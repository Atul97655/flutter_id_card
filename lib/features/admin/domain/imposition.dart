import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';

/// Sheet imposition: how many cards fit on a press sheet, and exactly where.
///
/// All arithmetic is in millimetres. The grid is computed from the selected
/// card size rather than hard-coded, because a school on 56 x 88 mm cards does
/// not get the same 25-up layout as one on 54 x 86 mm - and silently
/// overlapping cards would only be discovered after the sheet is printed.

/// A press sheet.
class SheetSpec {
  const SheetSpec({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.nominalCapacity,
  });

  final String id;
  final String name;
  final double widthMm;
  final double heightMm;

  /// The card count this sheet is *expected* to hold at the standard
  /// 54 x 86 mm size. Used only to warn when a different card size drops the
  /// real capacity below it.
  final int nominalCapacity;

  /// 12 x 18 inch, the standard digital press sheet. 5 x 5 = 25 cards at
  /// 54 x 86 mm, leaving 17.4 mm side and 13.6 mm head/foot margins.
  static const SheetSpec sheet12x18 = SheetSpec(
    id: '12x18',
    name: '12 x 18 in Sheet',
    widthMm: 304.8,
    heightMm: 457.2,
    nominalCapacity: 25,
  );

  /// A4 **landscape**, 297 x 210 mm.
  ///
  /// Landscape is not a preference, it is arithmetic: A4 portrait is 210 mm
  /// wide, which takes only floor(210/54) = 3 columns, and 297 mm tall, which
  /// takes floor(297/86) = 3 rows - 9 cards, one short of the required 10.
  /// Rotated, 297 mm takes 5 columns and 210 mm takes 2 rows = 10.
  static const SheetSpec a4Landscape = SheetSpec(
    id: 'a4',
    name: 'A4 Landscape',
    widthMm: 297,
    heightMm: 210,
    nominalCapacity: 10,
  );

  static const List<SheetSpec> all = <SheetSpec>[sheet12x18, a4Landscape];

  static SheetSpec fromId(String id) => all.firstWhere(
        (SheetSpec s) => s.id == id,
        orElse: () => sheet12x18,
      );
}

/// Where one card sits on a sheet, in millimetres from the sheet's top-left.
class CardSlot {
  const CardSlot({
    required this.column,
    required this.row,
    required this.xMm,
    required this.yMm,
  });

  final int column;
  final int row;
  final double xMm;
  final double yMm;
}

/// The computed layout for one sheet size + card size pairing.
class ImpositionGrid {
  const ImpositionGrid({
    required this.sheet,
    required this.cardSize,
    required this.columns,
    required this.rows,
    required this.marginLeftMm,
    required this.marginTopMm,
    required this.gutterMm,
    required this.warnings,
  });

  final SheetSpec sheet;
  final CardSize cardSize;
  final int columns;
  final int rows;

  /// Computed so the block of cards is centred on the sheet. Centring matters:
  /// most guillotines register off the sheet edge, so an off-centre block
  /// produces uneven trim on opposite sides.
  final double marginLeftMm;
  final double marginTopMm;

  final double gutterMm;

  /// Operator-facing problems - e.g. this card size cannot reach the sheet's
  /// nominal capacity.
  final List<String> warnings;

  int get capacity => columns * rows;

  bool get isUsable => capacity > 0;

  bool get hasWarnings => warnings.isNotEmpty;

  double get blockWidthMm =>
      columns * cardSize.widthMm + (columns - 1).clamp(0, columns) * gutterMm;

  double get blockHeightMm =>
      rows * cardSize.heightMm + (rows - 1).clamp(0, rows) * gutterMm;

  /// Top-left corner of every slot, in reading order (left to right, top to
  /// bottom) so sheet 1 holds the first N entries in the operator's list order.
  List<CardSlot> get slots {
    final List<CardSlot> result = <CardSlot>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        result.add(
          CardSlot(
            column: c,
            row: r,
            xMm: marginLeftMm + c * (cardSize.widthMm + gutterMm),
            yMm: marginTopMm + r * (cardSize.heightMm + gutterMm),
          ),
        );
      }
    }
    return result;
  }

  /// How many sheets [cardCount] entries need.
  int sheetsFor(int cardCount) {
    if (capacity <= 0 || cardCount <= 0) return 0;
    return (cardCount + capacity - 1) ~/ capacity;
  }

  /// Minimum white border kept clear on every side.
  ///
  /// Almost no office or production printer can image to the paper edge, and a
  /// card printed into the non-imageable margin comes out clipped. 5 mm is a
  /// safe floor across laser and inkjet devices.
  static const double minimumMarginMm = 5.0;

  /// Computes the grid.
  ///
  /// [gutterMm] defaults to 0 because ID cards are butt-cut: neighbouring cards
  /// share a single blade pass, which both saves sheet area and avoids a white
  /// sliver between cards. Pass a gutter only if each card carries its own
  /// bleed, in which case it must be at least twice the bleed or the artwork of
  /// adjacent cards will overlap.
  static ImpositionGrid compute({
    required SheetSpec sheet,
    required CardSize cardSize,
    double gutterMm = 0,
    double minMarginMm = minimumMarginMm,
  }) {
    final List<String> warnings = <String>[];

    final double usableWidth = sheet.widthMm - minMarginMm * 2;
    final double usableHeight = sheet.heightMm - minMarginMm * 2;

    // A card plus one gutter is the repeating unit; the last column needs no
    // trailing gutter, so add one back before dividing.
    final int columns = _fit(usableWidth, cardSize.widthMm, gutterMm);
    final int rows = _fit(usableHeight, cardSize.heightMm, gutterMm);

    if (columns == 0 || rows == 0) {
      warnings.add(
        '${cardSize.label} does not fit on ${sheet.name} '
        '(${_fmt(sheet.widthMm)} x ${_fmt(sheet.heightMm)} mm) with a '
        '${_fmt(minMarginMm)} mm printer margin. Choose a smaller card or a '
        'larger sheet.',
      );
      return ImpositionGrid(
        sheet: sheet,
        cardSize: cardSize,
        columns: 0,
        rows: 0,
        marginLeftMm: minMarginMm,
        marginTopMm: minMarginMm,
        gutterMm: gutterMm,
        warnings: warnings,
      );
    }

    final int capacity = columns * rows;
    if (capacity < sheet.nominalCapacity) {
      warnings.add(
        'Only $capacity cards fit on ${sheet.name} at ${cardSize.label} '
        '($columns x $rows), not the usual ${sheet.nominalCapacity}. '
        'More sheets will be needed.',
      );
    }

    final double blockWidth =
        columns * cardSize.widthMm + (columns - 1) * gutterMm;
    final double blockHeight = rows * cardSize.heightMm + (rows - 1) * gutterMm;

    return ImpositionGrid(
      sheet: sheet,
      cardSize: cardSize,
      columns: columns,
      rows: rows,
      marginLeftMm: (sheet.widthMm - blockWidth) / 2,
      marginTopMm: (sheet.heightMm - blockHeight) / 2,
      gutterMm: gutterMm,
      warnings: warnings,
    );
  }

  /// How many [itemMm]-wide items, separated by [gutterMm], fit in [availableMm].
  ///
  /// The epsilon absorbs floating-point error: 5 x 54 mm is exactly 270 mm, but
  /// binary arithmetic can land on 270.00000000000006 and lose a whole column.
  static int _fit(double availableMm, double itemMm, double gutterMm) {
    if (itemMm <= 0 || availableMm < itemMm) return 0;
    const double epsilon = 1e-6;
    return ((availableMm + gutterMm + epsilon) / (itemMm + gutterMm)).floor();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// Real resolution a photo achieves once placed on this sheet, for the
  /// pre-flight check.
  double photoDpi(int photoPixelWidth) => PrintUnits.effectiveDpi(
        pixels: photoPixelWidth,
        mm: PhotoSpec.widthMm,
      );

  @override
  String toString() =>
      'ImpositionGrid(${sheet.id}, ${cardSize.id}, ${columns}x$rows = $capacity)';
}
