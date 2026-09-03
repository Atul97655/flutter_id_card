/// Physical unit conversions for the print pipeline.
///
/// READ THIS BEFORE TOUCHING ANY LAYOUT CODE.
///
/// The whole system has one hard requirement: a card that is specified as
/// 54 x 86 mm must measure 54 x 86 mm under a ruler after printing. That is only
/// achievable if the print path never touches screen units.
///
/// The rules:
///   1. All card/layout geometry is authored and stored in millimetres.
///   2. Millimetres are converted to PostScript points exactly once, at the
///      boundary where geometry is handed to the `pdf` package. A PDF user-space
///      unit *is* a point, so this is the only conversion the PDF needs.
///   3. Font sizes are authored in **typographic points** and passed straight
///      through - `pdf` already interprets them as points.
///   4. Raster images are generated at `PrintUnits.printDpi` and placed into an
///      mm-sized box, so the effective resolution is preserved.
///   5. Flutter logical pixels (and `MediaQuery.devicePixelRatio`) appear ONLY
///      in the on-screen preview, and only via a single scale factor applied to
///      the same mm geometry. Never bake them into stored values.
///
/// The one conversion the PDF path uses is `PrintUnits.mmToPt`.
///
/// A bug in this file shifts every printed card, so it is unit-tested in
/// `test/print_units_test.dart`.
library;

final class PrintUnits {
  const PrintUnits._();

  /// Exact, by definition of the international inch.
  static const double mmPerInch = 25.4;

  /// A PostScript/DTP point is exactly 1/72 inch. This is the unit the `pdf`
  /// package uses for both page geometry and font sizes.
  static const double ptPerInch = 72.0;

  /// Minimum raster resolution for anything that ends up on a printed card.
  /// Below this, photos visibly halftone on a 54x86 mm card.
  static const double printDpi = 300.0;

  /// Standard bleed for trimmed cards. Artwork extends this far past the trim
  /// line on all four sides so a slightly misaligned guillotine cut does not
  /// expose white paper at the card edge.
  static const double defaultBleedMm = 3.0;

  /// Length of the crop marks drawn at each corner outside the trim box.
  static const double cropMarkLengthMm = 3.0;

  /// Gap between the trim line and where the crop mark starts, so the mark
  /// itself is never printed inside the finished card.
  static const double cropMarkOffsetMm = 1.0;

  /// Hairline weight for crop marks - thin enough to cut accurately along.
  static const double cropMarkWidthMm = 0.15;

  // ---------------------------------------------------------------------
  // Conversions
  // ---------------------------------------------------------------------

  /// Millimetres -> PostScript points. The single conversion used by the PDF
  /// builder. `54 mm` -> `153.07 pt`.
  static double mmToPt(double mm) => mm * ptPerInch / mmPerInch;

  /// PostScript points -> millimetres. Used when reading back page formats.
  static double ptToMm(double pt) => pt * mmPerInch / ptPerInch;

  /// Millimetres -> raster pixels at [dpi]. Used to decide how large a bitmap
  /// must be to fill a given mm-sized box without upscaling.
  static double mmToPx(double mm, {double dpi = printDpi}) => mm * dpi / mmPerInch;

  /// Raster pixels at [dpi] -> millimetres.
  static double pxToMm(double px, {double dpi = printDpi}) => px * mmPerInch / dpi;

  static double inchToMm(double inch) => inch * mmPerInch;

  static double mmToInch(double mm) => mm / mmPerInch;

  /// Typographic points -> millimetres. Used to reserve vertical space for a
  /// text row in an mm-based layout.
  static double ptToMmText(double pt) => ptToMm(pt);

  /// The actual DPI a bitmap of [pixels] px achieves when placed in a box of
  /// [mm] millimetres. Used by the pre-flight check to warn an operator that a
  /// photo is too low-resolution *before* a 25-card sheet is committed to film.
  static double effectiveDpi({required int pixels, required double mm}) {
    if (mm <= 0) return 0;
    return pixels / mmToInch(mm);
  }
}

/// The photo block on every card is a fixed physical size: 1.2 x 1.5 inch.
/// Values are derived rather than typed by hand so they can never drift apart.
final class PhotoSpec {
  const PhotoSpec._();

  static const double widthInch = 1.2;
  static const double heightInch = 1.5;

  /// 30.48 mm
  static const double widthMm = widthInch * PrintUnits.mmPerInch;

  /// 38.1 mm
  static const double heightMm = heightInch * PrintUnits.mmPerInch;

  /// 360 px at 300 DPI.
  static const int widthPx = 360;

  /// 450 px at 300 DPI.
  static const int heightPx = 450;

  /// Width / height = 0.8, i.e. the 4:5 portrait crop box shown in the camera
  /// guide overlay. Expressed w/h to match Flutter's `AspectRatio`.
  static const double aspectRatio = widthInch / heightInch;

  /// Where the centre of the subject's face should sit inside the crop, as a
  /// fraction of the frame height. Passport-style framing puts the head in the
  /// upper-middle, not dead centre, which reads as too low on a small card.
  static const double faceCentreYFraction = 0.42;

  /// Fraction of the frame height the head should occupy. Used to derive the
  /// zoom level from the ML Kit face bounding box.
  static const double targetHeadHeightFraction = 0.62;
}
