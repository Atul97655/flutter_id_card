import 'package:flutter_id_card/features/photo_capture/domain/photo_geometry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every crop the pipeline produces must be exactly 4:5, inside the source,
/// and at least 1 px. These tests pin those invariants across the awkward
/// cases - wide sources, tall sources, faces at the edge, tiny faces.
void expectValidCrop(PixelRect crop, int srcW, int srcH, {String? reason}) {
  expect(crop.left, greaterThanOrEqualTo(0), reason: reason);
  expect(crop.top, greaterThanOrEqualTo(0), reason: reason);
  expect(crop.right, lessThanOrEqualTo(srcW), reason: reason);
  expect(crop.bottom, lessThanOrEqualTo(srcH), reason: reason);
  expect(crop.width, greaterThan(0), reason: reason);
  expect(crop.height, greaterThan(0), reason: reason);
  // Integer rounding of a 4:5 box can be off by up to a pixel.
  expect(
    crop.aspectRatio,
    closeTo(PhotoSpec.aspectRatio, 0.02),
    reason: reason ?? 'crop must stay at the 1.2:1.5 print ratio',
  );
}

void main() {
  group('centreCrop', () {
    test('takes the tallest 4:5 box from a landscape source', () {
      final PixelRect crop =
          PhotoGeometry.centreCrop(sourceWidth: 1920, sourceHeight: 1080);

      expectValidCrop(crop, 1920, 1080);
      expect(crop.height, 1080);
      expect(crop.width, 864); // 1080 * 0.8
      expect(crop.centerX, closeTo(960, 1));
    });

    test('is width-limited on a narrow portrait source', () {
      final PixelRect crop =
          PhotoGeometry.centreCrop(sourceWidth: 600, sourceHeight: 2000);

      expectValidCrop(crop, 600, 2000);
      expect(crop.width, 600);
      expect(crop.height, 750); // 600 / 0.8
    });

    test('handles a source already at 4:5', () {
      final PixelRect crop =
          PhotoGeometry.centreCrop(sourceWidth: 360, sourceHeight: 450);
      expectValidCrop(crop, 360, 450);
      expect(crop.width, 360);
      expect(crop.height, 450);
    });

    test('survives a 1x1 source without dividing by zero', () {
      final PixelRect crop =
          PhotoGeometry.centreCrop(sourceWidth: 1, sourceHeight: 1);
      expect(crop.width, greaterThan(0));
      expect(crop.height, greaterThan(0));
    });
  });

  group('faceCrop framing', () {
    const int srcW = 1200;
    const int srcH = 1600;

    test('centres the face horizontally', () {
      const PixelRect face = PixelRect(left: 500, top: 400, width: 200, height: 260);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );

      expectValidCrop(crop, srcW, srcH);
      expect(crop.centerX, closeTo(face.centerX, 2));
    });

    test('places the face in the upper-middle, not dead centre', () {
      const PixelRect face = PixelRect(left: 500, top: 500, width: 200, height: 260);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );

      final double faceFraction = (face.centerY - crop.top) / crop.height;
      expect(
        faceFraction,
        closeTo(PhotoSpec.faceCentreYFraction, 0.05),
        reason: 'passport framing puts the head above centre',
      );
      expect(faceFraction, lessThan(0.5));
    });

    test('scales so the head fills the intended share of the frame', () {
      const PixelRect face = PixelRect(left: 500, top: 400, width: 200, height: 260);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );

      // The face box is smaller than the whole head, so the head's share of the
      // frame should exceed the raw face box's share.
      final double faceShare = face.height / crop.height;
      expect(faceShare, lessThan(PhotoSpec.targetHeadHeightFraction));
      expect(faceShare, greaterThan(0.3));
    });

    test('a larger face produces a tighter crop', () {
      final PixelRect small = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: const PixelRect(left: 550, top: 500, width: 100, height: 130),
      );
      final PixelRect large = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: const PixelRect(left: 400, top: 400, width: 400, height: 520),
      );

      expect(large.height, greaterThan(small.height));
    });
  });

  group('faceCrop edge handling', () {
    const int srcW = 1200;
    const int srcH = 1600;

    test('a face against the left edge slides the crop in, staying 4:5', () {
      const PixelRect face = PixelRect(left: 0, top: 400, width: 180, height: 240);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );
      expectValidCrop(crop, srcW, srcH, reason: 'face at left edge');
      expect(crop.left, 0);
    });

    test('a face against the right edge stays inside the source', () {
      const PixelRect face =
          PixelRect(left: srcW - 180, top: 400, width: 180, height: 240);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );
      expectValidCrop(crop, srcW, srcH, reason: 'face at right edge');
      expect(crop.right, lessThanOrEqualTo(srcW));
    });

    test('a face at the very top does not produce a negative origin', () {
      const PixelRect face = PixelRect(left: 500, top: 0, width: 200, height: 260);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );
      expectValidCrop(crop, srcW, srcH, reason: 'face at top edge');
      expect(crop.top, 0);
    });

    test('a face at the very bottom keeps the crop in bounds', () {
      const PixelRect face =
          PixelRect(left: 500, top: srcH - 260, width: 200, height: 260);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );
      expectValidCrop(crop, srcW, srcH, reason: 'face at bottom edge');
      expect(crop.bottom, lessThanOrEqualTo(srcH));
    });

    test('a face filling the frame is clamped to the source, not enlarged', () {
      const PixelRect face = PixelRect(left: 0, top: 0, width: srcW, height: srcH);
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: face,
      );
      expectValidCrop(crop, srcW, srcH, reason: 'face fills frame');
    });

    test('a zero-size face falls back to a centre crop', () {
      final PixelRect crop = PhotoGeometry.faceCrop(
        sourceWidth: srcW,
        sourceHeight: srcH,
        face: const PixelRect(left: 10, top: 10, width: 0, height: 0),
      );
      expect(
        crop.width,
        PhotoGeometry.centreCrop(sourceWidth: srcW, sourceHeight: srcH).width,
      );
    });

    test('stays valid across a sweep of face positions and sizes', () {
      for (final int w in <int>[80, 200, 400, 900]) {
        for (final int x in <int>[0, 150, 600, srcW - 80]) {
          for (final int y in <int>[0, 200, 900, srcH - 80]) {
            final PixelRect face = PixelRect(
              left: x.clamp(0, srcW - 1),
              top: y.clamp(0, srcH - 1),
              width: w.clamp(1, srcW),
              height: (w * 1.3).round().clamp(1, srcH),
            );
            expectValidCrop(
              PhotoGeometry.faceCrop(
                sourceWidth: srcW,
                sourceHeight: srcH,
                face: face,
              ),
              srcW,
              srcH,
              reason: 'face $face',
            );
          }
        }
      }
    });
  });

  group('print resolution checks', () {
    test('a 360x450 crop exactly meets the 300 DPI requirement', () {
      const PixelRect crop =
          PixelRect(left: 0, top: 0, width: 360, height: 450);
      expect(PhotoGeometry.meetsPrintResolution(crop), isTrue);
      expect(PhotoGeometry.effectiveDpi(crop), closeTo(300, 1e-6));
    });

    test('a smaller crop is flagged as below print resolution', () {
      const PixelRect crop =
          PixelRect(left: 0, top: 0, width: 240, height: 300);
      expect(PhotoGeometry.meetsPrintResolution(crop), isFalse);
      expect(PhotoGeometry.effectiveDpi(crop), closeTo(200, 1e-6));
    });

    test('a modern phone camera crop comfortably exceeds it', () {
      const PixelRect crop =
          PixelRect(left: 0, top: 0, width: 1200, height: 1500);
      expect(PhotoGeometry.meetsPrintResolution(crop), isTrue);
      expect(PhotoGeometry.effectiveDpi(crop), greaterThan(300));
    });
  });
}
