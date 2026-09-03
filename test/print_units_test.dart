import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests are the guard rail on the print pipeline. If any of them fail,
/// printed cards will come out the wrong physical size.
void main() {
  group('PrintUnits conversions', () {
    test('1 inch is 25.4 mm and 72 pt', () {
      expect(PrintUnits.inchToMm(1), 25.4);
      expect(PrintUnits.mmToPt(25.4), closeTo(72.0, 1e-9));
    });

    test('a 54 mm card edge is 153.07 pt', () {
      expect(PrintUnits.mmToPt(54), closeTo(153.0709, 1e-3));
    });

    test('an 86 mm card edge is 243.78 pt', () {
      expect(PrintUnits.mmToPt(86), closeTo(243.7795, 1e-3));
    });

    test('mm -> pt -> mm round-trips exactly', () {
      for (final double mm in <double>[52, 54, 56, 84, 86, 88, 210, 297, 304.8]) {
        expect(PrintUnits.ptToMm(PrintUnits.mmToPt(mm)), closeTo(mm, 1e-9));
      }
    });

    test('mm -> px at 300 DPI', () {
      // 25.4 mm is one inch, which is exactly 300 px at 300 DPI.
      expect(PrintUnits.mmToPx(25.4), closeTo(300, 1e-9));
      expect(PrintUnits.mmToPx(54), closeTo(637.795, 1e-3));
    });

    test('px -> mm round-trips', () {
      expect(PrintUnits.pxToMm(PrintUnits.mmToPx(38.1)), closeTo(38.1, 1e-9));
    });

    test('effectiveDpi reports the real resolution of a placed bitmap', () {
      // 360 px across a 30.48 mm (1.2 in) box is exactly 300 DPI.
      expect(
        PrintUnits.effectiveDpi(pixels: 360, mm: 30.48),
        closeTo(300, 1e-6),
      );
      // Half the pixels in the same box is half the resolution.
      expect(
        PrintUnits.effectiveDpi(pixels: 180, mm: 30.48),
        closeTo(150, 1e-6),
      );
    });

    test('effectiveDpi does not divide by zero', () {
      expect(PrintUnits.effectiveDpi(pixels: 360, mm: 0), 0);
    });
  });

  group('PhotoSpec', () {
    test('is exactly 1.2 x 1.5 inch', () {
      expect(PhotoSpec.widthInch, 1.2);
      expect(PhotoSpec.heightInch, 1.5);
    });

    test('derived millimetres match the spec', () {
      expect(PhotoSpec.widthMm, closeTo(30.48, 1e-9));
      expect(PhotoSpec.heightMm, closeTo(38.1, 1e-9));
    });

    test('360 x 450 px fills the photo box at exactly 300 DPI', () {
      expect(
        PrintUnits.mmToPx(PhotoSpec.widthMm),
        closeTo(PhotoSpec.widthPx.toDouble(), 1e-6),
      );
      expect(
        PrintUnits.mmToPx(PhotoSpec.heightMm),
        closeTo(PhotoSpec.heightPx.toDouble(), 1e-6),
      );
    });

    test('aspect ratio is the 4:5 crop box shown in the camera overlay', () {
      expect(PhotoSpec.aspectRatio, closeTo(0.8, 1e-9));
      expect(
        PhotoSpec.widthPx / PhotoSpec.heightPx,
        closeTo(PhotoSpec.aspectRatio, 1e-9),
      );
    });
  });

  group('CardSize', () {
    test('exposes exactly the six specified sizes', () {
      expect(CardSize.all.length, 6);
      expect(CardSize.vertical.length, 3);
      expect(CardSize.horizontal.length, 3);
    });

    test('classifies orientation from the dimensions, not the id', () {
      expect(CardSize.v54x86.orientation, CardOrientation.vertical);
      expect(CardSize.h86x54.orientation, CardOrientation.horizontal);
    });

    test('converts its own edges to points', () {
      expect(CardSize.v54x86.widthPt, closeTo(153.0709, 1e-3));
      expect(CardSize.v54x86.heightPt, closeTo(243.7795, 1e-3));
    });

    test('adds bleed to both edges of each axis', () {
      // 3 mm of bleed grows a 54 mm edge by 6 mm, not 3.
      expect(CardSize.v54x86.widthWithBleedMm(3), 60);
      expect(CardSize.v54x86.heightWithBleedMm(3), 92);
    });

    test('aspect ratio is width over height', () {
      expect(CardSize.v54x86.aspectRatio, closeTo(54 / 86, 1e-9));
    });

    test('an unknown id falls back to the default rather than throwing', () {
      // A bad id arriving in a synced school config must not brick the app.
      expect(CardSize.fromId('nonsense'), CardSize.defaultSize);
      expect(CardSize.fromId(null), CardSize.defaultSize);
    });

    test('known ids resolve to themselves', () {
      for (final CardSize size in CardSize.all) {
        expect(CardSize.fromId(size.id), size, reason: size.id);
      }
    });
  });
}
