import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_id_card/features/photo_capture/domain/photo_adjustments.dart';
import 'package:flutter_id_card/features/photo_capture/domain/photo_geometry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

/// Result of running a capture through the pipeline.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.faceDetected,
    required this.backgroundRemoved,
    required this.sourceDpi,
    required this.warnings,
    this.averageLuminance = 128.0,
    this.isLowLight = false,
  });

  final Uint8List pngBytes;
  final int width;
  final int height;
  final bool faceDetected;
  final bool backgroundRemoved;

  /// Effective DPI the *source* crop achieved before resampling. Below 300 the
  /// photo was upscaled and will look soft in print.
  final double sourceDpi;

  final List<String> warnings;
  final double averageLuminance;
  final bool isLowLight;

  bool get meetsPrintResolution => sourceDpi >= PrintUnits.printDpi - 1;
}

/// Turns a raw camera or gallery image into the exact 360 x 450 px, white-backed
/// portrait the card expects.
///
/// Pipeline order matters and is not arbitrary:
///   1. Face detection and segmentation run on the ORIGINAL file, because ML
///      Kit gets better results at native resolution.
///   2. The image is downscaled to a working size before any per-pixel Dart
///      loop. Compositing a 12 MP image pixel-by-pixel in Dart takes seconds;
///      at the working size it is milliseconds, and the final output is only
///      360 x 450 anyway.
///   3. Background replacement happens BEFORE cropping, so the mask - which is
///      in source coordinates - lines up.
///   4. Crop, then resample to exactly 360 x 450.
///   5. Brightness/contrast/saturation last, so adjustments are judged on what
///      actually prints.
///
/// The pixel work runs in a background isolate via [compute]; ML Kit calls must
/// stay on the main isolate because they cross a platform channel.
class PhotoProcessor {
  PhotoProcessor();

  /// Long edge the image is reduced to before per-pixel work. 1600 px keeps
  /// roughly 3.5x the final resolution, which is ample headroom for cropping
  /// while keeping the composite fast.
  static const int workingLongEdge = 1600;

  FaceDetector? _faceDetector;
  SelfieSegmenter? _segmenter;

  FaceDetector get _faces => _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          // Landmarks/classification are not needed - only the bounding box
          // drives the crop, and disabling the rest is measurably faster.
          enableLandmarks: false,
          enableClassification: false,
          enableTracking: false,
          minFaceSize: 0.15,
        ),
      );

  SelfieSegmenter get _selfie => _segmenter ??= SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: true,
      );

  Future<void> dispose() async {
    await _faceDetector?.close();
    await _segmenter?.close();
    _faceDetector = null;
    _segmenter = null;
  }

  /// Runs the full pipeline over the image at [sourcePath].
  Future<ProcessedPhoto> process({
    required String sourcePath,
    required PhotoAdjustments adjustments,
    required int backgroundArgb,
  }) async {
    final File file = File(sourcePath);
    if (!file.existsSync()) {
      throw const PhotoProcessingException('The captured image could not be found.');
    }

    final Uint8List sourceBytes = await file.readAsBytes();
    final InputImage input = InputImage.fromFilePath(sourcePath);

    // --- ML Kit (main isolate, platform channels) ---------------------
    final List<String> warnings = <String>[];

    PixelRect? faceBox;
    if (adjustments.autoFrame) {
      faceBox = await _detectFace(input, warnings);
    }

    _MaskData? mask;
    if (adjustments.removeBackground) {
      mask = await _segment(input, warnings);
    }

    // --- Pixel work (background isolate) ------------------------------
    final _ProcessRequest request = _ProcessRequest(
      sourceBytes: sourceBytes,
      maskConfidences: mask?.confidences,
      maskWidth: mask?.width ?? 0,
      maskHeight: mask?.height ?? 0,
      faceLeft: faceBox?.left ?? -1,
      faceTop: faceBox?.top ?? -1,
      faceWidth: faceBox?.width ?? 0,
      faceHeight: faceBox?.height ?? 0,
      backgroundArgb: backgroundArgb,
      brightness: adjustments.brightness,
      contrast: adjustments.contrast,
      saturation: adjustments.saturation,
      nudgeX: adjustments.nudgeX,
      nudgeY: adjustments.nudgeY,
    );

    final _ProcessResponse response = await compute(_runPipeline, request);

    if (response.error != null) {
      throw PhotoProcessingException(response.error!);
    }

    if (response.sourceDpi < PrintUnits.printDpi - 1) {
      warnings.add(
        'This photo is only ${response.sourceDpi.round()} DPI at print size '
        '(300 is the minimum). It will look soft on the printed card - retake '
        'it closer, or with a higher camera resolution.',
      );
    }

    if (response.isLowLight) {
      warnings.add(
        'Low light detected (brightness ${response.averageLuminance.round()}/255). '
        'The photo may look dark or noisy when printed. Retake with better lighting or increase brightness.',
      );
    }

    return ProcessedPhoto(
      pngBytes: response.pngBytes!,
      width: PhotoSpec.widthPx,
      height: PhotoSpec.heightPx,
      faceDetected: faceBox != null,
      backgroundRemoved: mask != null,
      sourceDpi: response.sourceDpi,
      warnings: warnings,
      averageLuminance: response.averageLuminance,
      isLowLight: response.isLowLight,
    );
  }

  /// Largest detected face, which is the subject when a classmate wanders into
  /// the background.
  Future<PixelRect?> _detectFace(InputImage input, List<String> warnings) async {
    try {
      final List<Face> found = await _faces.processImage(input);
      if (found.isEmpty) {
        warnings.add(
          'No face was detected, so the photo has been centre-cropped. '
          'Check the framing before saving.',
        );
        return null;
      }
      if (found.length > 1) {
        warnings.add(
          '${found.length} faces were detected - the largest was used. '
          'Check the framing.',
        );
      }
      final Face subject = found.reduce(
        (Face a, Face b) =>
            a.boundingBox.width * a.boundingBox.height >=
                    b.boundingBox.width * b.boundingBox.height
                ? a
                : b,
      );
      final ui.Rect box = subject.boundingBox;
      return PixelRect(
        left: box.left.round(),
        top: box.top.round(),
        width: box.width.round(),
        height: box.height.round(),
      );
    } on Object catch (e) {
      // Detection failing is recoverable - fall back to a centre crop.
      warnings.add('Face detection unavailable ($e). Using a centre crop.');
      return null;
    }
  }

  Future<_MaskData?> _segment(InputImage input, List<String> warnings) async {
    try {
      final SegmentationMask? mask = await _selfie.processImage(input);
      if (mask == null) {
        warnings.add('Background removal produced no result; the original '
            'background has been kept.');
        return null;
      }
      return _MaskData(
        confidences: Float32List.fromList(mask.confidences),
        width: mask.width,
        height: mask.height,
      );
    } on Object catch (e) {
      warnings.add('Background removal unavailable ($e). Original background kept.');
      return null;
    }
  }
}

class PhotoProcessingException implements Exception {
  const PhotoProcessingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _MaskData {
  const _MaskData({
    required this.confidences,
    required this.width,
    required this.height,
  });

  final Float32List confidences;
  final int width;
  final int height;
}

// ---------------------------------------------------------------------
// Isolate payloads. Plain data only - nothing here may hold a platform
// channel, a File handle or anything else that cannot cross an isolate.
// ---------------------------------------------------------------------

class _ProcessRequest {
  const _ProcessRequest({
    required this.sourceBytes,
    required this.maskConfidences,
    required this.maskWidth,
    required this.maskHeight,
    required this.faceLeft,
    required this.faceTop,
    required this.faceWidth,
    required this.faceHeight,
    required this.backgroundArgb,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.nudgeX,
    required this.nudgeY,
  });

  final Uint8List sourceBytes;
  final Float32List? maskConfidences;
  final int maskWidth;
  final int maskHeight;
  final int faceLeft;
  final int faceTop;
  final int faceWidth;
  final int faceHeight;
  final int backgroundArgb;
  final double brightness;
  final double contrast;
  final double saturation;
  final double nudgeX;
  final double nudgeY;

  bool get hasFace => faceLeft >= 0 && faceWidth > 0 && faceHeight > 0;
  bool get hasMask => maskConfidences != null && maskWidth > 0 && maskHeight > 0;
}

class _ProcessResponse {
  const _ProcessResponse.success(
    this.pngBytes,
    this.sourceDpi, {
    this.averageLuminance = 128.0,
    this.isLowLight = false,
  }) : error = null;

  const _ProcessResponse.failure(this.error)
      : pngBytes = null,
        sourceDpi = 0,
        averageLuminance = 0,
        isLowLight = false;

  final Uint8List? pngBytes;
  final double sourceDpi;
  final double averageLuminance;
  final bool isLowLight;
  final String? error;
}

/// Runs in a background isolate. Must stay a top-level function.
_ProcessResponse _runPipeline(_ProcessRequest req) {
  try {
    final img.Image? decoded = img.decodeImage(req.sourceBytes);
    if (decoded == null) {
      return const _ProcessResponse.failure(
        'That file is not an image we can read.',
      );
    }

    // Some cameras write the sensor orientation into EXIF rather than rotating
    // the pixels; without this the subject arrives sideways.
    img.Image working = img.bakeOrientation(decoded);

    final int originalWidth = working.width;

    // Downscale before any per-pixel loop. See the class doc for why.
    final int longEdge = math.max(working.width, working.height);
    if (longEdge > PhotoProcessor.workingLongEdge) {
      final double scale = PhotoProcessor.workingLongEdge / longEdge;
      working = img.copyResize(
        working,
        width: math.max(1, (working.width * scale).round()),
        height: math.max(1, (working.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }

    // Face coordinates are in original-image space; bring them into working
    // space with the same factor the image was scaled by.
    final double toWorking = working.width / originalWidth;

    if (req.hasMask) {
      working = _compositeBackground(
        working,
        req.maskConfidences!,
        req.maskWidth,
        req.maskHeight,
        req.backgroundArgb,
      );
    }

    final PixelRect crop = req.hasFace
        ? PhotoGeometry.faceCrop(
            sourceWidth: working.width,
            sourceHeight: working.height,
            face: PixelRect(
              left: (req.faceLeft * toWorking).round(),
              top: (req.faceTop * toWorking).round(),
              width: (req.faceWidth * toWorking).round(),
              height: (req.faceHeight * toWorking).round(),
            ),
          )
        : PhotoGeometry.centreCrop(
            sourceWidth: working.width,
            sourceHeight: working.height,
          );

    final PixelRect nudged = _applyNudge(
      crop,
      working.width,
      working.height,
      req.nudgeX,
      req.nudgeY,
    );

    img.Image out = img.copyCrop(
      working,
      x: nudged.left,
      y: nudged.top,
      width: nudged.width,
      height: nudged.height,
    );

    // Resolution is measured on the crop taken from the ORIGINAL image, not the
    // downscaled working copy - otherwise the working downscale would make
    // every photo look under-resolution.
    final double sourceCropWidth = nudged.width / toWorking;
    final double sourceDpi = PrintUnits.effectiveDpi(
      pixels: sourceCropWidth.round(),
      mm: PhotoSpec.widthMm,
    );

    out = img.copyResize(
      out,
      width: PhotoSpec.widthPx,
      height: PhotoSpec.heightPx,
      interpolation: img.Interpolation.cubic,
    );

    // Sample luminance across the crop before user manual adjustments
    // Rec. 601 luma formula: Y = 0.299*R + 0.587*G + 0.114*B
    double totalLuma = 0;
    int sampledPixels = 0;
    const int step = 4;
    for (int y = 0; y < out.height; y += step) {
      for (int x = 0; x < out.width; x += step) {
        final img.Pixel p = out.getPixel(x, y);
        totalLuma += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        sampledPixels++;
      }
    }
    final double avgLuma = sampledPixels > 0 ? totalLuma / sampledPixels : 128.0;
    final bool isLowLight = avgLuma < 60.0;

    out = _applyAdjustments(out, req.brightness, req.contrast, req.saturation);

    return _ProcessResponse.success(
      img.encodePng(out),
      sourceDpi,
      averageLuminance: avgLuma,
      isLowLight: isLowLight,
    );
  } on Object catch (e) {
    return _ProcessResponse.failure('Could not process the photo: $e');
  }
}

/// Replaces the background with a solid colour using the segmentation mask.
///
/// The mask is usually a different resolution from the image, so it is sampled
/// proportionally. Confidences are passed through a smoothstep rather than a
/// hard threshold: a hard cut leaves a jagged, aliased outline around hair,
/// whereas a soft ramp blends the last few pixels and reads cleanly at card
/// size.
img.Image _compositeBackground(
  img.Image source,
  Float32List confidences,
  int maskWidth,
  int maskHeight,
  int backgroundArgb,
) {
  final int bgR = (backgroundArgb >> 16) & 0xFF;
  final int bgG = (backgroundArgb >> 8) & 0xFF;
  final int bgB = backgroundArgb & 0xFF;

  final double xRatio = maskWidth / source.width;
  final double yRatio = maskHeight / source.height;

  for (int y = 0; y < source.height; y++) {
    final int my = (y * yRatio).floor().clamp(0, maskHeight - 1);
    final int rowOffset = my * maskWidth;

    for (int x = 0; x < source.width; x++) {
      final int mx = (x * xRatio).floor().clamp(0, maskWidth - 1);
      final int index = rowOffset + mx;
      if (index < 0 || index >= confidences.length) continue;

      // ML Kit's selfie segmenter reports, per pixel, the confidence that the
      // pixel belongs to the PERSON. 1.0 = definitely foreground.
      final double alpha = _smoothstep(0.35, 0.68, confidences[index]);
      if (alpha >= 0.999) continue; // fully foreground, leave untouched

      final img.Pixel pixel = source.getPixel(x, y);
      source.setPixelRgb(
        x,
        y,
        (pixel.r * alpha + bgR * (1 - alpha)).round().clamp(0, 255),
        (pixel.g * alpha + bgG * (1 - alpha)).round().clamp(0, 255),
        (pixel.b * alpha + bgB * (1 - alpha)).round().clamp(0, 255),
      );
    }
  }
  return source;
}

double _smoothstep(double edge0, double edge1, double x) {
  if (edge1 <= edge0) return x >= edge1 ? 1 : 0;
  final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Shifts the crop by a fraction of its own size, then clamps it back inside
/// the image so a nudge can never sample outside the source.
PixelRect _applyNudge(
  PixelRect crop,
  int sourceWidth,
  int sourceHeight,
  double nudgeX,
  double nudgeY,
) {
  if (nudgeX == 0 && nudgeY == 0) return crop;

  final int dx = (crop.width * nudgeX).round();
  final int dy = (crop.height * nudgeY).round();

  final int left = (crop.left + dx).clamp(0, math.max(0, sourceWidth - crop.width));
  final int top = (crop.top + dy).clamp(0, math.max(0, sourceHeight - crop.height));

  return PixelRect(
    left: left,
    top: top,
    width: crop.width,
    height: crop.height,
  );
}

/// Brightness, contrast and saturation in one pass.
///
/// Done by hand rather than with three `package:image` filter calls because
/// each of those allocates and walks the whole bitmap again; one pass over
/// 162,000 pixels keeps the slider preview responsive.
img.Image _applyAdjustments(
  img.Image source,
  double brightness,
  double contrast,
  double saturation,
) {
  if (brightness == 0 && contrast == 0 && saturation == 0) return source;

  // Brightness as an additive offset in 0..255 space; +-1.0 maps to +-96,
  // which is a strong but still recoverable correction.
  final double brightnessOffset = brightness * 96;

  // Standard contrast factor, pivoting around mid-grey.
  final double c = contrast.clamp(-1.0, 1.0) * 96;
  final double contrastFactor = (259 * (c + 255)) / (255 * (259 - c));

  final double satFactor = 1 + saturation.clamp(-1.0, 1.0);

  for (int y = 0; y < source.height; y++) {
    for (int x = 0; x < source.width; x++) {
      final img.Pixel pixel = source.getPixel(x, y);

      double r = pixel.r.toDouble();
      double g = pixel.g.toDouble();
      double b = pixel.b.toDouble();

      if (brightness != 0) {
        r += brightnessOffset;
        g += brightnessOffset;
        b += brightnessOffset;
      }

      if (contrast != 0) {
        r = contrastFactor * (r - 128) + 128;
        g = contrastFactor * (g - 128) + 128;
        b = contrastFactor * (b - 128) + 128;
      }

      if (saturation != 0) {
        // Rec. 601 luma, which is what looks right for skin tones.
        final double luma = 0.299 * r + 0.587 * g + 0.114 * b;
        r = luma + (r - luma) * satFactor;
        g = luma + (g - luma) * satFactor;
        b = luma + (b - luma) * satFactor;
      }

      source.setPixelRgb(
        x,
        y,
        r.round().clamp(0, 255),
        g.round().clamp(0, 255),
        b.round().clamp(0, 255),
      );
    }
  }
  return source;
}
