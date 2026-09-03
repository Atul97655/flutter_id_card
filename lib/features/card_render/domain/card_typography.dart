import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';

/// Per-field print styling, in typographic points.
///
/// The sizes and colours below are fixed by the specification:
///
///   Name           8 pt  Bold     Red
///   Father's Name  7 pt  Regular  Blue
///   Class          8 pt  Regular  Red
///   DOB            7 pt  Regular  Blue
///   Mobile         7 pt  Regular  Red
///   Address        5 pt  Regular  Red
///
/// Two fields are not covered by that table, so they are assigned here to match
/// the field they sit next to on the card:
///   Div         -> 8 pt Red   (always printed beside Class)
///   Blood Group -> 7 pt Blue  (grouped with the other secondary details)
/// Change these two if the organisation wants them treated differently; the
/// six specified rows above should not be changed.
///
/// "Red" and "Blue" are the school's configurable primary/secondary colours,
/// not literal hex values - see [ColorToken].
class CardTypography {
  const CardTypography({
    required this.sizePt,
    required this.bold,
    required this.color,
    this.maxLines = 1,
  });

  final double sizePt;
  final bool bold;
  final ColorRef color;
  final int maxLines;

  static const ColorRef _red = ColorRef.token(ColorToken.primary);
  static const ColorRef _blue = ColorRef.token(ColorToken.secondary);

  static const Map<StudentField, CardTypography> byField =
      <StudentField, CardTypography>{
    StudentField.name: CardTypography(sizePt: 8, bold: true, color: _red),
    StudentField.fatherName: CardTypography(sizePt: 7, bold: false, color: _blue),
    StudentField.studentClass: CardTypography(sizePt: 8, bold: false, color: _red),
    StudentField.division: CardTypography(sizePt: 8, bold: false, color: _red),
    StudentField.bloodGroup: CardTypography(sizePt: 7, bold: false, color: _blue),
    StudentField.dob: CardTypography(sizePt: 7, bold: false, color: _blue),
    StudentField.mobile: CardTypography(sizePt: 7, bold: false, color: _red),
    StudentField.address: CardTypography(sizePt: 5, bold: false, color: _red, maxLines: 2),
  };

  static CardTypography forField(StudentField field) =>
      byField[field] ??
      const CardTypography(sizePt: 7, bold: false, color: _red);

  /// Multiplier from font size to line box height. 1.18 is a conventional
  /// single-line leading for a humanist sans at small sizes; below about 1.1
  /// ascenders and descenders start colliding between rows.
  static const double lineHeightFactor = 1.18;

  CardTypography scaled(double factor) => CardTypography(
        sizePt: sizePt * factor,
        bold: bold,
        color: color,
        maxLines: maxLines,
      );
}
