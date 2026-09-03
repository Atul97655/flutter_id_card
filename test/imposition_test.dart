import 'package:flutter_id_card/features/admin/domain/imposition.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('12 x 18 in sheet', () {
    test('holds exactly 25 standard 54x86 cards in a 5x5 grid', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v54x86,
      );

      expect(grid.columns, 5);
      expect(grid.rows, 5);
      expect(grid.capacity, 25);
      expect(grid.hasWarnings, isFalse);
    });

    test('leaves the margins the specification calls for', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v54x86,
      );

      // 5 x 54 = 270 mm of cards on a 304.8 mm sheet -> 17.4 mm each side.
      expect(grid.blockWidthMm, closeTo(270, 1e-9));
      expect(grid.marginLeftMm, closeTo(17.4, 1e-6));

      // 5 x 86 = 430 mm on a 457.2 mm sheet -> 13.6 mm head and foot.
      expect(grid.blockHeightMm, closeTo(430, 1e-9));
      expect(grid.marginTopMm, closeTo(13.6, 1e-6));
    });

    test('the block is centred, so both trims are equal', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v54x86,
      );
      final double rightMargin =
          SheetSpec.sheet12x18.widthMm - grid.marginLeftMm - grid.blockWidthMm;
      final double bottomMargin =
          SheetSpec.sheet12x18.heightMm - grid.marginTopMm - grid.blockHeightMm;

      expect(rightMargin, closeTo(grid.marginLeftMm, 1e-9));
      expect(bottomMargin, closeTo(grid.marginTopMm, 1e-9));
    });

    test('warns instead of overlapping when a larger card cannot reach 25', () {
      // 56 x 88 mm: 5 x 56 = 280 mm still fits the width, but 5 x 88 = 440 mm
      // exceeds the 447.2 mm usable height only marginally - check whichever
      // way it lands, the warning and the capacity agree.
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v56x88,
      );

      expect(grid.capacity, greaterThan(0));
      if (grid.capacity < 25) {
        expect(grid.hasWarnings, isTrue);
        expect(grid.warnings.single, contains('not the usual 25'));
      } else {
        expect(grid.hasWarnings, isFalse);
      }
    });

    test('smaller cards yield at least the nominal capacity', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v52x84,
      );
      expect(grid.capacity, greaterThanOrEqualTo(25));
      expect(grid.hasWarnings, isFalse);
    });

    test('horizontal cards impose too', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.h86x54,
      );
      // 304.8 / 86 = 3 columns; 457.2 / 54 = 8 rows.
      expect(grid.columns, 3);
      expect(grid.rows, 8);
      expect(grid.capacity, 24);
    });
  });

  group('A4 sheet', () {
    test('landscape holds the required 10 cards in a 5x2 grid', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.a4Landscape,
        cardSize: CardSize.v54x86,
      );

      expect(grid.columns, 5);
      expect(grid.rows, 2);
      expect(grid.capacity, 10);
      expect(grid.hasWarnings, isFalse);
    });

    test('portrait A4 genuinely cannot fit 10 - which is why we use landscape',
        () {
      // This is the arithmetic behind the design decision, pinned so nobody
      // "fixes" the orientation later.
      const SheetSpec a4Portrait = SheetSpec(
        id: 'a4p',
        name: 'A4 Portrait',
        widthMm: 210,
        heightMm: 297,
        nominalCapacity: 10,
      );
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: a4Portrait,
        cardSize: CardSize.v54x86,
      );

      expect(grid.columns, 3);
      expect(grid.rows, 3);
      expect(grid.capacity, 9);
      expect(grid.capacity, lessThan(10));
      expect(grid.hasWarnings, isTrue);
    });

    test('block is centred on the landscape sheet', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.a4Landscape,
        cardSize: CardSize.v54x86,
      );
      // 5 x 54 = 270 on 297 -> 13.5 mm each side.
      expect(grid.marginLeftMm, closeTo(13.5, 1e-9));
      // 2 x 86 = 172 on 210 -> 19 mm top and bottom.
      expect(grid.marginTopMm, closeTo(19, 1e-9));
    });
  });

  group('slot positions', () {
    final ImpositionGrid grid = ImpositionGrid.compute(
      sheet: SheetSpec.sheet12x18,
      cardSize: CardSize.v54x86,
    );

    test('produces one slot per card, in reading order', () {
      final List<CardSlot> slots = grid.slots;
      expect(slots.length, 25);
      expect(slots.first.column, 0);
      expect(slots.first.row, 0);
      expect(slots[1].column, 1);
      expect(slots[1].row, 0);
      expect(slots[5].column, 0);
      expect(slots[5].row, 1);
      expect(slots.last.column, 4);
      expect(slots.last.row, 4);
    });

    test('first slot starts at the computed margin', () {
      expect(grid.slots.first.xMm, closeTo(grid.marginLeftMm, 1e-9));
      expect(grid.slots.first.yMm, closeTo(grid.marginTopMm, 1e-9));
    });

    test('adjacent butt-cut cards touch exactly, with no gap or overlap', () {
      final List<CardSlot> slots = grid.slots;
      expect(
        slots[1].xMm - slots[0].xMm,
        closeTo(CardSize.v54x86.widthMm, 1e-9),
      );
      expect(
        slots[5].yMm - slots[0].yMm,
        closeTo(CardSize.v54x86.heightMm, 1e-9),
      );
    });

    test('no slot extends past the sheet', () {
      for (final CardSlot slot in grid.slots) {
        expect(
          slot.xMm + grid.cardSize.widthMm,
          lessThanOrEqualTo(grid.sheet.widthMm + 1e-9),
        );
        expect(
          slot.yMm + grid.cardSize.heightMm,
          lessThanOrEqualTo(grid.sheet.heightMm + 1e-9),
        );
      }
    });
  });

  group('gutters', () {
    test('a gutter reduces capacity and separates the cards', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v54x86,
        gutterMm: 6, // twice a 3 mm bleed
      );

      expect(grid.capacity, lessThan(25));
      final List<CardSlot> slots = grid.slots;
      if (slots.length > 1 && grid.columns > 1) {
        expect(
          slots[1].xMm - slots[0].xMm,
          closeTo(CardSize.v54x86.widthMm + 6, 1e-9),
        );
      }
    });

    test('block width accounts for gutters between, not after, the cards', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v54x86,
        gutterMm: 5,
      );
      expect(
        grid.blockWidthMm,
        closeTo(grid.columns * 54 + (grid.columns - 1) * 5, 1e-9),
      );
    });
  });

  group('sheet counting', () {
    final ImpositionGrid grid = ImpositionGrid.compute(
      sheet: SheetSpec.sheet12x18,
      cardSize: CardSize.v54x86,
    );

    test('rounds up to a whole sheet', () {
      expect(grid.sheetsFor(0), 0);
      expect(grid.sheetsFor(1), 1);
      expect(grid.sheetsFor(25), 1);
      expect(grid.sheetsFor(26), 2);
      expect(grid.sheetsFor(50), 2);
      expect(grid.sheetsFor(51), 3);
    });

    test('a class of 240 needs 10 sheets', () {
      expect(grid.sheetsFor(240), 10);
    });
  });

  group('degenerate cases', () {
    test('a card larger than the sheet reports zero capacity and warns', () {
      const SheetSpec tiny = SheetSpec(
        id: 'tiny',
        name: 'Tiny',
        widthMm: 40,
        heightMm: 40,
        nominalCapacity: 1,
      );
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: tiny,
        cardSize: CardSize.v54x86,
      );

      expect(grid.capacity, 0);
      expect(grid.isUsable, isFalse);
      expect(grid.hasWarnings, isTrue);
      expect(grid.warnings.single, contains('does not fit'));
      expect(grid.slots, isEmpty);
      expect(grid.sheetsFor(10), 0);
    });

    test('floating-point error never costs a whole column', () {
      // 5 x 54 = 270 exactly, but binary arithmetic can produce 270.0000000001
      // and floor() would then give 4 columns instead of 5.
      const SheetSpec exact = SheetSpec(
        id: 'exact',
        name: 'Exact fit',
        widthMm: 270 + ImpositionGrid.minimumMarginMm * 2,
        heightMm: 430 + ImpositionGrid.minimumMarginMm * 2,
        nominalCapacity: 25,
      );
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: exact,
        cardSize: CardSize.v54x86,
      );
      expect(grid.columns, 5);
      expect(grid.rows, 5);
    });
  });

  group('photo pre-flight', () {
    test('reports true DPI of a placed photo', () {
      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: SheetSpec.sheet12x18,
        cardSize: CardSize.v54x86,
      );
      // The pipeline's 360 px photo lands at exactly 300 DPI.
      expect(grid.photoDpi(360), closeTo(300, 1e-6));
      // A phone thumbnail would be flagged.
      expect(grid.photoDpi(120), closeTo(100, 1e-6));
    });
  });
}
