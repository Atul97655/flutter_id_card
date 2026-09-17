import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/photo_capture/data/photo_processor.dart';
import 'package:flutter_id_card/features/photo_capture/data/photo_storage.dart';
import 'package:flutter_id_card/features/photo_capture/domain/photo_adjustments.dart';
import 'package:flutter_id_card/features/photo_capture/presentation/widgets/crop_guide_overlay.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Capture -> background removal -> adjust -> save.
///
/// Pops with the absolute path of the processed 360 x 450 PNG, or null if the
/// operator backed out.
class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key, this.existingPath});

  /// Path of a photo already attached to the entry, so "Retake" can offer to
  /// keep the current one.
  final String? existingPath;

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

enum _Stage { permission, camera, processing, review }

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen>
    with WidgetsBindingObserver {
  final PhotoProcessor _processor = PhotoProcessor();
  final PhotoStorage _storage = PhotoStorage();
  final ImagePicker _picker = ImagePicker();

  CameraController? _camera;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIndex = 0;

  _Stage _stage = _Stage.permission;
  String? _sourcePath;
  ProcessedPhoto? _result;
  PhotoAdjustments _adjustments = PhotoAdjustments.neutral;
  String? _error;

  FaceDetector? _liveFaceDetector;
  FaceDetector get _liveDetector => _liveFaceDetector ??= FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.15,
    ),
  );

  bool _isDetecting = false;
  DateTime _lastDetectionTime = DateTime.now();
  String _liveStatusMessage = '1.2 x 1.5 in  -  keep the eyes on the line';
  Color _liveBorderColor = Colors.white;
  Color _liveStatusColor = Colors.white;

  /// Guards against overlapping reprocess runs while a slider is dragged.
  bool _processing = false;
  bool _reprocessQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_camera?.value.isStreamingImages ?? false) {
      unawaited(_camera?.stopImageStream());
    }
    _camera?.dispose();
    unawaited(_liveFaceDetector?.close());
    unawaited(_processor.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OS reclaims the camera when the app goes to the background; without
    // this the preview comes back as a frozen green frame.
    final CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream());
      }
      controller.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed && _stage == _Stage.camera) {
      unawaited(_initCamera());
    }
  }

  // ------------------------------------------------------------------
  // Setup
  // ------------------------------------------------------------------

  Future<void> _start() async {
    final PermissionStatus status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      await _initCamera();
      return;
    }

    setState(() {
      _stage = _Stage.permission;
      _error = status.isPermanentlyDenied
          ? 'Camera access is blocked. Enable it in Settings, or pick an '
                'existing photo from the gallery.'
          : 'Camera access is needed to take the student photo. You can also '
                'pick an existing photo from the gallery.';
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _stage = _Stage.permission;
          _error =
              'No camera was found on this device. Use the gallery instead.';
        });
        return;
      }

      // Prefer the rear camera: it has the better sensor, and an operator
      // photographing someone else is standing behind the device.
      _cameraIndex = _cameras.indexWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;

      await _openCamera(_cameraIndex);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.permission;
        _error = 'Could not start the camera: ${e.description ?? e.code}';
      });
    }
  }

  Future<void> _openCamera(int index) async {
    await _stopLiveStream();
    await _camera?.dispose();

    final CameraController controller = CameraController(
      _cameras[index],
      // veryHigh keeps the source well above the 360 x 450 target even after
      // the face crop takes a fraction of the frame.
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _camera = controller;
      _cameraIndex = index;
      _stage = _Stage.camera;
      _error = null;
    });

    unawaited(_startLiveFaceDetection());
  }

  Future<void> _stopLiveStream() async {
    final CameraController? controller = _camera;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
  }

  Future<void> _startLiveFaceDetection() async {
    final CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      await controller.startImageStream((CameraImage image) {
        final DateTime now = DateTime.now();
        if (_isDetecting ||
            now.difference(_lastDetectionTime).inMilliseconds < 350) {
          return;
        }
        _processLiveFrame(image);
      });
    } catch (_) {
      // If image stream is unsupported on this device/platform, fail gracefully
      // and keep the static guide overlay.
    }
  }

  Future<void> _processLiveFrame(CameraImage image) async {
    if (_isDetecting || !mounted || _stage != _Stage.camera) return;
    _isDetecting = true;
    _lastDetectionTime = DateTime.now();

    try {
      if (_cameraIndex >= _cameras.length) return;
      final CameraDescription camera = _cameras[_cameraIndex];
      final InputImage? input = _buildInputImage(image, camera);
      if (input == null) return;

      final List<Face> faces = await _liveDetector.processImage(input);
      if (!mounted || _stage != _Stage.camera) return;

      setState(() {
        if (faces.isEmpty) {
          _liveStatusMessage = 'Position face inside the box';
          _liveBorderColor = Colors.white70;
          _liveStatusColor = Colors.white70;
        } else if (faces.length == 1) {
          _liveStatusMessage = 'Face detected • Hold steady';
          _liveBorderColor = Colors.greenAccent;
          _liveStatusColor = Colors.greenAccent;
        } else {
          _liveStatusMessage =
              '${faces.length} faces detected • Only 1 student allowed';
          _liveBorderColor = Colors.orangeAccent;
          _liveStatusColor = Colors.orangeAccent;
        }
      });
    } catch (_) {
      // Ignore individual live frame parsing errors
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final InputImageRotation? rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final int? rawFormat = image.format.raw is int
        ? image.format.raw as int
        : null;
    final InputImageFormat? format = rawFormat != null
        ? InputImageFormatValue.fromRawValue(rawFormat)
        : null;
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final Uint8List allBytes = Uint8List(
      image.planes.fold(0, (count, plane) => count + plane.bytes.length),
    );
    int offset = 0;
    for (final Plane plane in image.planes) {
      allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    return InputImage.fromBytes(
      bytes: allBytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Capture
  // ------------------------------------------------------------------

  Future<void> _capture() async {
    final CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    try {
      await _stopLiveStream();
      final XFile shot = await controller.takePicture();
      await _useSource(shot.path);
    } on CameraException catch (e) {
      _showError('Capture failed: ${e.description ?? e.code}');
      if (mounted && _stage == _Stage.camera) {
        unawaited(_startLiveFaceDetection());
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      await _stopLiveStream();
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        // Do not let the picker downscale: the pipeline needs the resolution
        // for the crop, and it does its own resampling at the end.
        imageQuality: 100,
      );
      if (picked == null) {
        if (mounted && _stage == _Stage.camera) {
          unawaited(_startLiveFaceDetection());
        }
        return;
      }
      await _useSource(picked.path);
    } on Object catch (e) {
      _showError('Could not open the gallery: $e');
    }
  }

  Future<void> _editExistingPhoto() async {
    if (widget.existingPath == null) return;
    await _stopLiveStream();
    final String? raw = _storage.rawPathFor(widget.existingPath);
    final String source = (raw != null && File(raw).existsSync())
        ? raw
        : widget.existingPath!;
    await _useSource(source);
  }

  Future<void> _useSource(String path) async {
    setState(() {
      _sourcePath = path;
      _stage = _Stage.processing;
      _error = null;
    });
    await _reprocess();
  }

  /// Runs the pipeline for the current source and adjustments.
  ///
  /// Slider drags fire this repeatedly, so overlapping runs are collapsed: if a
  /// run is already in flight the request is queued and re-run once, which
  /// keeps the preview current without stacking isolate work.
  Future<void> _reprocess() async {
    final String? source = _sourcePath;
    if (source == null) return;

    if (_processing) {
      _reprocessQueued = true;
      return;
    }
    _processing = true;

    try {
      final SchoolConfig? config = ref.read(schoolConfigProvider).value;
      final ProcessedPhoto processed = await _processor.process(
        sourcePath: source,
        adjustments: _adjustments,
        backgroundArgb:
            config?.photoBackgroundHex ??
            SchoolConfig.kDefaultPhotoBackgroundHex,
      );

      if (!mounted) return;
      setState(() {
        _result = processed;
        _stage = _Stage.review;
        _error = null;
      });
    } on PhotoProcessingException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.review;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.review;
        _error = 'Could not process the photo: $e';
      });
    } finally {
      _processing = false;
      if (_reprocessQueued && mounted) {
        _reprocessQueued = false;
        unawaited(_reprocess());
      }
    }
  }

  void _updateAdjustments(PhotoAdjustments next) {
    setState(() => _adjustments = next);
    unawaited(_reprocess());
  }

  Future<void> _save() async {
    final ProcessedPhoto? processed = _result;
    if (processed == null) return;

    try {
      final String path = await _storage.save(
        processed.pngBytes,
        sourceRawPath: _sourcePath,
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(path);
      } else {
        Navigator.of(context).pop(path);
      }
    } on Object catch (e) {
      _showError('Could not save the photo: $e');
    }
  }

  void _retake() {
    setState(() {
      _sourcePath = null;
      _result = null;
      _adjustments = _adjustments.reset();
      _error = null;
      _liveStatusMessage = '1.2 x 1.5 in  -  keep the eyes on the line';
      _liveBorderColor = Colors.white;
      _liveStatusColor = Colors.white;
      _stage = _camera == null ? _Stage.permission : _Stage.camera;
    });
    if (_camera == null) {
      unawaited(_start());
    } else {
      unawaited(_startLiveFaceDetection());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: StatusColors.failed),
      );
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_stage == _Stage.review ? 'Edit Photo' : 'Student Photo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (_stage == _Stage.review && _camera != null) {
              _retake();
            } else if (context.canPop()) {
              context.pop();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: <Widget>[
          if (_stage == _Stage.camera && _cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: 'Switch camera',
              onPressed: () =>
                  _openCamera((_cameraIndex + 1) % _cameras.length),
            ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          if (_stage == _Stage.review && _camera != null) {
            _retake();
          } else if (context.canPop()) {
            context.pop();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: switch (_stage) {
          _Stage.permission => _permissionView(),
          _Stage.camera => _cameraView(),
          _Stage.processing => _processingView(),
          _Stage.review => _reviewView(),
        },
      ),
    );
  }

  Widget _permissionView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.photo_camera_outlined,
              size: 56,
              color: Colors.white54,
            ),
            const SizedBox(height: 18),
            Text(
              _error ?? 'Camera access is needed to take the student photo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.5),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Allow camera'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
            ),
            const SizedBox(height: 10),
            const TextButton(
              onPressed: openAppSettings,
              child: Text('Open app settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView() {
    final CameraController? controller = _camera;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Fit the whole sensor frame on screen rather than filling it:
              // the operator must be able to see what falls outside the crop.
              Center(
                child: AspectRatio(
                  aspectRatio: 1 / controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
              CropGuideOverlay(
                borderColor: _liveBorderColor,
                statusMessage: _liveStatusMessage,
                statusColor: _liveStatusColor,
              ),
            ],
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  iconSize: 30,
                  color: Colors.white,
                  tooltip: 'Choose from gallery',
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                if (widget.existingPath != null)
                  IconButton(
                    iconSize: 28,
                    color: Colors.amberAccent,
                    tooltip: 'Re-edit existing photo',
                    onPressed: _editExistingPhoto,
                    icon: const Icon(Icons.auto_fix_high),
                  ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _liveBorderColor, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: widget.existingPath == null
                      ? null
                      : IconButton(
                          iconSize: 28,
                          color: Colors.white,
                          tooltip: 'Keep current photo and return',
                          onPressed: () => context.pop(widget.existingPath),
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _processingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 18),
          Text(
            'Removing background and framing...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _reviewView() {
    final ProcessedPhoto? processed = _result;

    return SafeArea(
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: <Widget>[
                  if (_error != null) _errorCard(_error!),
                  if (processed != null) ...<Widget>[
                    _preview(processed),
                    const SizedBox(height: 14),
                    _resolutionBadge(processed),
                    for (final String w in processed.warnings) ...<Widget>[
                      const SizedBox(height: 8),
                      _warningCard(w),
                    ],
                    const SizedBox(height: 20),
                    _controls(),
                  ],
                ],
              ),
            ),
          ),
          _reviewActions(processed != null),
        ],
      ),
    );
  }

  Widget _preview(ProcessedPhoto processed) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 200,
          height: 250, // 1.2 : 1.5
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.memory(
                processed.pngBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              if (_processing)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resolutionBadge(ProcessedPhoto processed) {
    final bool ok = processed.meetsPrintResolution;
    final Color color = ok ? StatusColors.synced : StatusColors.pending;

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                ok ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                ok
                    ? 'Print ready - ${PhotoSpec.widthPx} x ${PhotoSpec.heightPx} px '
                          'at ${PrintUnits.printDpi.round()} DPI'
                    : 'Low resolution - ${processed.sourceDpi.round()} DPI',
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (processed.isLowLight) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.wb_sunny_outlined,
                  size: 14,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Low Lighting Detected (${processed.averageLuminance.round()}/255)',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Zoom first: framing is judged before colour, and it is the control
        // an operator reaches for most after a wide capture.
        _slider(
          label: 'Zoom',
          icon: Icons.zoom_in,
          value: _adjustments.zoom,
          min: 0,
          apply: (double v) => _adjustments.copyWith(zoom: v),
        ),
        _slider(
          label: 'Brightness',
          icon: Icons.brightness_6_outlined,
          value: _adjustments.brightness,
          apply: (double v) => _adjustments.copyWith(brightness: v),
        ),
        _slider(
          label: 'Contrast',
          icon: Icons.contrast,
          value: _adjustments.contrast,
          apply: (double v) => _adjustments.copyWith(contrast: v),
        ),
        _slider(
          label: 'Saturation',
          icon: Icons.palette_outlined,
          value: _adjustments.saturation,
          apply: (double v) => _adjustments.copyWith(saturation: v),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'Replace background',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: const Text(
            'On-device removal, filled with the school background colour',
            style: TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
          value: _adjustments.removeBackground,
          onChanged: (bool v) =>
              _updateAdjustments(_adjustments.copyWith(removeBackground: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'Auto-centre on face',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: const Text(
            'Off uses a plain centre crop',
            style: TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
          value: _adjustments.autoFrame,
          onChanged: (bool v) =>
              _updateAdjustments(_adjustments.copyWith(autoFrame: v)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nudge framing',
          style: TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        _nudgePad(),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _adjustments.isNeutral
                ? null
                : () => _updateAdjustments(_adjustments.reset()),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset adjustments'),
          ),
        ),
      ],
    );
  }

  /// One adjustment slider.
  ///
  /// [apply] builds the new adjustments from a slider value, so the caller owns
  /// which field moves. This used to switch on the label string, which meant
  /// renaming a label silently rewired it to the wrong control.
  Widget _slider({
    required String label,
    required IconData icon,
    required double value,
    required PhotoAdjustments Function(double) apply,
    double min = -1,
    double max = 1,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(),
            label: value == 0 ? '0' : (value * 100).round().toString(),
            // Live-update the local value so the thumb tracks the finger, but
            // only reprocess on release - firing the isolate on every pixel of
            // a drag would make the slider feel laggy.
            onChanged: (double v) => setState(() => _adjustments = apply(v)),
            onChangeEnd: (double v) => _updateAdjustments(apply(v)),
          ),
        ),
      ],
    );
  }

  Widget _nudgePad() {
    const double step = 0.04;

    Widget arrow(IconData icon, double dx, double dy, String tooltip) {
      return IconButton(
        tooltip: tooltip,
        color: Colors.white,
        onPressed: () => _updateAdjustments(
          _adjustments.copyWith(
            nudgeX: (_adjustments.nudgeX + dx).clamp(-0.5, 0.5),
            nudgeY: (_adjustments.nudgeY + dy).clamp(-0.5, 0.5),
          ),
        ),
        icon: Icon(icon),
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          arrow(Icons.keyboard_arrow_left, -step, 0, 'Move crop left'),
          Column(
            children: <Widget>[
              arrow(Icons.keyboard_arrow_up, 0, -step, 'Move crop up'),
              arrow(Icons.keyboard_arrow_down, 0, step, 'Move crop down'),
            ],
          ),
          arrow(Icons.keyboard_arrow_right, step, 0, 'Move crop right'),
        ],
      ),
    );
  }

  Widget _reviewActions(bool canSave) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: Colors.black,
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _retake,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: canSave && !_processing ? _save : null,
              icon: const Icon(Icons.check),
              label: const Text('Use Photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) =>
      _banner(message, StatusColors.failed, Icons.error_outline);

  Widget _warningCard(String message) =>
      _banner(message, StatusColors.pending, Icons.warning_amber_rounded);

  Widget _banner(String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper so the photo bytes can be shown without a temp file.
typedef PhotoBytes = Uint8List;

/// True when a readable file exists at [path].
bool photoFileExists(String? path) =>
    path != null && path.isNotEmpty && File(path).existsSync();
