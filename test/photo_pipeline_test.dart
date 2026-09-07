import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_id_card/features/photo_capture/data/photo_processor.dart';
import 'package:flutter_id_card/features/photo_capture/data/photo_storage.dart';
import 'package:flutter_id_card/features/photo_capture/domain/photo_adjustments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PhotoProcessor processor;
  late PhotoStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('id_card_test_');
    processor = PhotoProcessor();
    storage = PhotoStorage(baseDirectory: tempDir);
  });

  tearDown(() async {
    await processor.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Low-light luminance detection', () {
    test('detects underexposed dark photo and issues low light warning', () async {
      // Create a 800x1000 very dark image (RGB: 20, 20, 20 => luma ~20)
      final img.Image darkImage = img.Image(width: 800, height: 1000);
      img.fill(darkImage, color: img.ColorRgb8(20, 20, 20));
      final Uint8List darkBytes = Uint8List.fromList(img.encodeJpg(darkImage));

      final File testFile = File('${tempDir.path}/dark_test.jpg');
      await testFile.writeAsBytes(darkBytes);

      final ProcessedPhoto result = await processor.process(
        sourcePath: testFile.path,
        adjustments: const PhotoAdjustments(
          brightness: 0,
          contrast: 0,
          saturation: 0,
          removeBackground: false,
          autoFrame: false,
          nudgeX: 0,
          nudgeY: 0,
        ),
        backgroundArgb: 0xFFFFFFFF,
      );

      expect(result.isLowLight, isTrue);
      expect(result.averageLuminance, lessThan(60.0));
      expect(
        result.warnings.any((w) => w.contains('Low light detected')),
        isTrue,
        reason: 'Low light warning must be present in warnings list',
      );
    });

    test('well-lit photo does not trigger low light warning', () async {
      // Create a 800x1000 bright image (RGB: 200, 200, 200 => luma ~200)
      final img.Image brightImage = img.Image(width: 800, height: 1000);
      img.fill(brightImage, color: img.ColorRgb8(200, 200, 200));
      final Uint8List brightBytes = Uint8List.fromList(img.encodeJpg(brightImage));

      final File testFile = File('${tempDir.path}/bright_test.jpg');
      await testFile.writeAsBytes(brightBytes);

      final ProcessedPhoto result = await processor.process(
        sourcePath: testFile.path,
        adjustments: const PhotoAdjustments(
          brightness: 0,
          contrast: 0,
          saturation: 0,
          removeBackground: false,
          autoFrame: false,
          nudgeX: 0,
          nudgeY: 0,
        ),
        backgroundArgb: 0xFFFFFFFF,
      );

      expect(result.isLowLight, isFalse);
      expect(result.averageLuminance, greaterThanOrEqualTo(60.0));
      expect(
        result.warnings.any((w) => w.contains('Low light detected')),
        isFalse,
      );
    });
  });

  group('Dual image storage', () {
    test('raw capture is preserved alongside processed photo and cleans up on delete', () async {
      final File rawSource = File('${tempDir.path}/original_capture.jpg');
      await rawSource.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));

      final Uint8List dummyPng = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

      // Save processed photo with raw source
      final String processedPath = await storage.save(
        dummyPng,
        sourceRawPath: rawSource.path,
      );

      expect(File(processedPath).existsSync(), isTrue);

      // Verify raw file was created and is discoverable via rawPathFor
      final String? rawPath = storage.rawPathFor(processedPath);
      expect(rawPath, isNotNull);
      expect(File(rawPath!).existsSync(), isTrue);
      expect(rawPath, endsWith('_raw.jpg'));

      // Delete processed photo - should also delete raw file
      await storage.delete(processedPath);
      expect(File(processedPath).existsSync(), isFalse);
      expect(File(rawPath).existsSync(), isFalse);
    });

    test('rawPathFor returns null when no raw counterpart exists', () {
      expect(storage.rawPathFor('${tempDir.path}/nonexistent.png'), isNull);
    });
  });
}
