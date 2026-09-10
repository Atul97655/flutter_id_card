/// Operator-controlled image corrections, applied after cropping.
///
/// Ranges are centred on 0 = "no change" so a reset is unambiguous and the
/// sliders read naturally. They are stored with the draft so re-editing a photo
/// starts from where the operator left off rather than from neutral.
class PhotoAdjustments {
  const PhotoAdjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.removeBackground = true,
    this.autoFrame = true,
    this.nudgeX = 0,
    this.nudgeY = 0,
    this.zoom = 0,
  });

  static const PhotoAdjustments neutral = PhotoAdjustments();

  /// -1.0 (much darker) .. 0 (unchanged) .. 1.0 (much brighter).
  final double brightness;

  /// -1.0 (flat) .. 0 .. 1.0 (punchy).
  final double contrast;

  /// -1.0 (greyscale) .. 0 .. 1.0 (vivid).
  final double saturation;

  final bool removeBackground;

  /// When true the crop is centred on the detected face; when false the
  /// operator has taken manual control and we keep a plain centre crop.
  final bool autoFrame;

  /// Manual framing offsets as a fraction of the crop size, applied on top of
  /// the automatic face centring. Lets an operator fix an unusual pose without
  /// abandoning auto-framing entirely.
  final double nudgeX;
  final double nudgeY;

  /// Crop tightness. 0 = the framing the detector chose, 1.0 = the tightest
  /// allowed crop. Negative is not offered: pulling wider than the detected
  /// frame would sample outside the source and letterbox the card's photo box.
  ///
  /// Applied by shrinking the crop window, so zooming in raises the effective
  /// resolution of the face rather than upscaling pixels.
  final double zoom;

  /// The most the crop window may shrink. A face at 45% of the original crop
  /// is already tighter than any of the reference cards, and going further
  /// starts cutting foreheads and chins.
  static const double maxZoomShrink = 0.55;

  bool get isNeutral =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      nudgeX == 0 &&
      nudgeY == 0 &&
      zoom == 0;

  /// Crop-window scale for [zoom]: 1.0 at rest, shrinking as zoom rises.
  double get cropScale => 1 - (zoom.clamp(0.0, 1.0) * maxZoomShrink);

  PhotoAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    bool? removeBackground,
    bool? autoFrame,
    double? nudgeX,
    double? nudgeY,
    double? zoom,
  }) {
    return PhotoAdjustments(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      removeBackground: removeBackground ?? this.removeBackground,
      autoFrame: autoFrame ?? this.autoFrame,
      nudgeX: nudgeX ?? this.nudgeX,
      nudgeY: nudgeY ?? this.nudgeY,
      zoom: zoom ?? this.zoom,
    );
  }

  PhotoAdjustments reset() => PhotoAdjustments(
        removeBackground: removeBackground,
        autoFrame: autoFrame,
      );
}
