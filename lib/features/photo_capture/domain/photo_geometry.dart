import 'dart:math' as math;

import 'package:flutter_id_card/shared/print/print_units.dart';

/// An axis-aligned rectangle in source-image pixel coordinates.
class PixelRect {
  const PixelRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  double get aspectRatio => height == 0 ? 0 : width / height;

  @override
  String toString() => 'PixelRect($left, $top, $width x $height)';
}

/// Pure crop arithmetic for the photo pipeline.
///
/// Kept free of ML Kit, `dart:ui` and `package:image` so the framing rules can
/// be unit-tested without a camera, a model or a decoded bitmap. The processor
/// calls this, then applies the result.
///
/// The output is always the 1.2 : 1.5 inch (4:5 portrait) box the card
/// reserves. Getting this wrong shows up as squashed or off-centre heads on
/// every printed card, so the invariants are tested rather than eyeballed.
final class PhotoGeometry {
  const PhotoGeometry._();

  /// Largest 4:5 rectangle centred in the source. Used when no face is found.
  static PixelRect centreCrop({required int sourceWidth, required int sourceHeight}) {
    return _fitAspect(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      centerX: sourceWidth / 2,
      centerY: sourceHeight / 2,
      desiredHeight: sourceHeight.toDouble(),
    );
  }

  /// Crop that frames [face] the way a passport photo does.
  ///
  /// Three things are being satisfied at once:
  ///   1. The head occupies [PhotoSpec.targetHeadHeightFraction] of the frame
  ///      height, so heads are a consistent size card to card.
  ///   2. The face centre sits at [PhotoSpec.faceCentreYFraction] down the
  ///      frame - upper-middle, not dead centre, which reads as too low.
  ///   3. The face is centred horizontally.
  ///
  /// Where those conflict with the edges of the source image, the crop is
  /// slid back inside the bounds rather than being allowed to sample outside
  /// it, and shrunk only if it genuinely does not fit.
  static PixelRect faceCrop({
    required int sourceWidth,
    required int sourceHeight,
    required PixelRect face,
  }) {
    if (face.height <= 0 || face.width <= 0) {
      return centreCrop(sourceWidth: sourceWidth, sourceHeight: sourceHeight);
    }

    // ML Kit's box covers roughly the face, not the whole head. Scaling up
    // accounts for hair above and chin-to-neck below; without it every subject
    // comes out cropped too tight.
    const double headToFaceBoxRatio = 1.42;
    final double headHeight = face.height * headToFaceBoxRatio;

    final double desiredHeight = headHeight / PhotoSpec.targetHeadHeightFraction;

    return _fitAspect(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      centerX: face.centerX,
      // Solve for the crop centre from where we want the face to land:
      // faceCentreY = cropTop + H * faceCentreYFraction, and
      // cropCentreY = cropTop + H / 2.
      centerY: face.centerY + desiredHeight * (0.5 - PhotoSpec.faceCentreYFraction),
      desiredHeight: desiredHeight,
    );
  }

  /// Builds a 4:5 rect of [desiredHeight] around a centre, clamped into the
  /// source. Shared by both crop modes so the clamping rules cannot diverge.
  static PixelRect _fitAspect({
    required int sourceWidth,
    required int sourceHeight,
    required double centerX,
    required double centerY,
    required double desiredHeight,
  }) {
    const double ratio = PhotoSpec.aspectRatio; // width / height = 0.8

    double height = desiredHeight;
    double width = height * ratio;

    // Shrink to fit whichever axis is binding, preserving the ratio exactly.
    if (width > sourceWidth) {
      width = sourceWidth.toDouble();
      height = width / ratio;
    }
    if (height > sourceHeight) {
      height = sourceHeight.toDouble();
      width = height * ratio;
    }

    // Slide - do not shrink - to bring the box inside the source.
    double left = centerX - width / 2;
    double top = centerY - height / 2;
    left = left.clamp(0, math.max(0, sourceWidth - width));
    top = top.clamp(0, math.max(0, sourceHeight - height));

    // The epsilon matters: 1080 * 0.8 is exactly 864, but in binary it lands on
    // 863.9999999999999 and a bare floor() would silently throw away a pixel
    // column on every exact-fit source.
    const double epsilon = 1e-6;

    int l = left.floor();
    int t = top.floor();
    final int w = (width + epsilon).floor();
    final int h = (height + epsilon).floor();

    // Pull back if rounding pushed the far edge past the source.

    if (l + w > sourceWidth) l = sourceWidth - w;
    if (t + h > sourceHeight) t = sourceHeight - h;

    return PixelRect(
      left: math.max(0, l),
      top: math.max(0, t),
      width: math.max(1, math.min(w, sourceWidth)),
      height: math.max(1, math.min(h, sourceHeight)),
    );
  }

  /// Whether a source image has the resolution to fill the printed photo box
  /// at [PrintUnits.printDpi] without upscaling.
  ///
  /// Upscaling is not fatal - the card still prints - but the operator should
  /// be told, because a soft photo is only obvious once it is on paper.
  static bool meetsPrintResolution(PixelRect crop) =>
      crop.width >= PhotoSpec.widthPx && crop.height >= PhotoSpec.heightPx;

  /// Real DPI a crop achieves in the printed photo box.
  static double effectiveDpi(PixelRect crop) =>
      PrintUnits.effectiveDpi(pixels: crop.width, mm: PhotoSpec.widthMm);
}
