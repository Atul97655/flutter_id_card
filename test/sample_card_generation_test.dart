import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Writes real, openable sample cards to `build/sample_cards/`.
///
/// This doubles as an end-to-end smoke test of the whole print path - fonts,
/// template parsing, photo embedding, PDF geometry - and gives something that
/// can be opened in a PDF viewer and physically measured against a ruler, which
/// is the acceptance criterion the specification actually asks for.
///
/// Run just this file with:
///   flutter test test/sample_card_generation_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outDir;

  setUpAll(() {
    outDir = Directory('build/sample_cards')..createSync(recursive: true);
  });

  test('generates printable sample cards at true size', () async {
    final IdCardRenderer renderer = await IdCardRenderer.load();

    // Synthetic subject photo at exactly the print resolution the pipeline
    // targets: 360 x 450 px = 1.2 x 1.5 in at 300 DPI.
    final File photoFile = File('${outDir.path}/sample_photo.png')
      ..writeAsBytesSync(_syntheticPortrait());
    final File logoFile = File('${outDir.path}/sample_logo.png')
      ..writeAsBytesSync(_syntheticLogo());

    final StudentEntry entry = StudentEntry(
      id: 'sample',
      schoolId: 'sample',
      name: 'RAMESH KUMAR PATIL',
      fatherName: 'SURESH KUMAR PATIL',
      studentClass: '10',
      division: 'A',
      bloodGroup: 'O+',
      dob: DateTime(2012, 4, 17),
      mobile: '9876543210',
      address: '12/A, MG ROAD, NEAR BUS STAND, HUBBALLI - 580020',
      localPhotoPath: photoFile.path,
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
    );

    final SchoolConfig baseConfig = SchoolConfig(
      id: 'sample',
      name: 'ST JOHN SAMARITAN SCHOOL',
      addressLine: 'ANAND NAGAR, HUBBALLI - 580025',
      contactLine: 'Office: 0836-2345678   |   info@stjohns.edu.in',
      localLogoPath: logoFile.path,
      enabledFieldKeys: SchoolConfig.allFieldKeys,
    );

    // 1. Vertical, all fields on - the worst case for vertical space.
    await _write(
      outDir,
      'vertical_54x86_all_fields.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig,
        template: await _template('assets/templates/default_vertical.json'),
        size: CardSize.v54x86,
      ),
    );

    // 2. Vertical with a typical field set, matching the reference designs.
    await _write(
      outDir,
      'vertical_54x86_typical.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig.copyWith(
          enabledFieldKeys: <String>{
            'name',
            'photo',
            'fatherName',
            'dob',
            'mobile',
            'address',
          },
        ),
        template: await _template('assets/templates/default_vertical.json'),
        size: CardSize.v54x86,
      ),
    );

    // 3. Horizontal, all fields on.
    await _write(
      outDir,
      'horizontal_86x54_all_fields.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig.copyWith(templateId: 'default_horizontal'),
        template: await _template('assets/templates/default_horizontal.json'),
        size: CardSize.h86x54,
      ),
    );

    // 4. Vertical with 3 mm bleed and crop marks - what goes to the printer.
    await _write(
      outDir,
      'vertical_54x86_bleed_cropmarks.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig,
        template: await _template('assets/templates/default_vertical.json'),
        size: CardSize.v54x86,
        bleedMm: PrintUnits.defaultBleedMm,
        cropMarks: true,
      ),
    );

    // 5. A school with its own palette, proving colours are not hard-coded.
    await _write(
      outDir,
      'vertical_54x86_custom_colours.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig.copyWith(
          name: 'GADAG PUBLIC SCHOOL',
          addressLine: 'NEAR S.M.K. NAGAR, BALAGANUR ROAD, GADAG',
          headerColorHex: 0xFF9C1AB1,
          primaryColorHex: 0xFF111111,
          secondaryColorHex: 0xFF9C1AB1,
        ),
        template: await _template('assets/templates/default_vertical.json'),
        size: CardSize.v54x86,
      ),
    );

    // 6. The three additional template styles, drawn from the reference set.
    await _write(
      outDir,
      'style_framed_vertical.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig.copyWith(
          templateId: 'framed_vertical',
          headerColorHex: 0xFF29B6F6,
        ),
        template: await _template('assets/templates/framed_vertical.json'),
        size: CardSize.v54x86,
      ),
    );

    await _write(
      outDir,
      'style_side_panel_horizontal.pdf',
      await renderer.buildSingleCardPdf(
        entry: entry,
        config: baseConfig.copyWith(
          templateId: 'side_panel_horizontal',
          headerColorHex: 0xFF1A47C4,
        ),
        template: await _template('assets/templates/side_panel_horizontal.json'),
        size: CardSize.h86x54,
      ),
    );

    // 7. The division-colour set: one school, six divisions, six colours.
    //    This mirrors the Sacred Heart Convent reference exactly - same layout
    //    throughout, only the accent colour changes with the student's Div.
    const Map<String, int> divisionPalette = <String, int>{
      'A': 0xFFE01B1B, // red
      'B': 0xFF1A1AE0, // blue
      'C': 0xFFE0189C, // pink
      'D': 0xFF14A05A, // green
      'E': 0xFFF07A16, // orange
      'F': 0xFF7B1FA2, // purple
    };

    final SchoolConfig conventConfig = baseConfig.copyWith(
      name: 'SACRED HEART CONVENT',
      addressLine: 'PRE-PRIMARY SCHOOL, KESHWAPUR HUBBALLI',
      contactLine: 'Mob: 9538848187',
      templateId: 'div_badge_vertical',
      divisionColors: divisionPalette,
      // Only the fields the reference card actually carries.
      enabledFieldKeys: <String>{'name', 'photo', 'division', 'mobile', 'address'},
    );

    final CardTemplate divTemplate =
        await _template('assets/templates/div_badge_vertical.json');

    for (final String division in divisionPalette.keys) {
      await _write(
        outDir,
        'division_${division}_card.pdf',
        await renderer.buildSingleCardPdf(
          entry: entry.copyWith(division: division),
          config: conventConfig,
          template: divTemplate,
          size: CardSize.v54x86,
        ),
      );
    }

    final List<FileSystemEntity> written = outDir
        .listSync()
        .where((FileSystemEntity f) => f.path.endsWith('.pdf'))
        .toList();
    // 5 originals + 2 new styles + 6 division cards.
    expect(written.length, 13);
  });
}

Future<CardTemplate> _template(String asset) async {
  final String raw = await rootBundle.loadString(asset);
  return CardTemplate.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

Future<void> _write(Directory dir, String name, Uint8List bytes) async {
  await File('${dir.path}/$name').writeAsBytes(bytes);
  expect(bytes.length, greaterThan(500), reason: name);
}

/// A neutral head-and-shoulders placeholder at the exact target resolution.
/// Stands in for a real capture so the sample cards show realistic framing.
Uint8List _syntheticPortrait() {
  final img.Image canvas = img.Image(
    width: PhotoSpec.widthPx,
    height: PhotoSpec.heightPx,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  final int cx = canvas.width ~/ 2;

  // Shoulders.
  img.fillCircle(
    canvas,
    x: cx,
    y: (canvas.height * 1.02).round(),
    radius: (canvas.width * 0.52).round(),
    color: img.ColorRgb8(150, 165, 185),
  );
  // Neck.
  img.fillRect(
    canvas,
    x1: cx - (canvas.width * 0.11).round(),
    y1: (canvas.height * 0.52).round(),
    x2: cx + (canvas.width * 0.11).round(),
    y2: (canvas.height * 0.80).round(),
    color: img.ColorRgb8(196, 168, 148),
  );
  // Head, positioned to the passport-style upper-centre framing the capture
  // screen aims for.
  img.fillCircle(
    canvas,
    x: cx,
    y: (canvas.height * PhotoSpec.faceCentreYFraction).round(),
    radius: (canvas.width * 0.28).round(),
    color: img.ColorRgb8(212, 182, 160),
  );
  // Hair.
  img.fillCircle(
    canvas,
    x: cx,
    y: (canvas.height * 0.30).round(),
    radius: (canvas.width * 0.27).round(),
    color: img.ColorRgb8(58, 44, 38),
  );
  img.fillRect(
    canvas,
    x1: cx - (canvas.width * 0.27).round(),
    y1: (canvas.height * 0.26).round(),
    x2: cx + (canvas.width * 0.27).round(),
    y2: (canvas.height * 0.36).round(),
    color: img.ColorRgb8(58, 44, 38),
  );
  img.fillCircle(
    canvas,
    x: cx,
    y: (canvas.height * PhotoSpec.faceCentreYFraction).round(),
    radius: (canvas.width * 0.235).round(),
    color: img.ColorRgb8(212, 182, 160),
  );

  return img.encodePng(canvas);
}

/// Simple circular emblem standing in for a school crest.
Uint8List _syntheticLogo() {
  const int size = 240;
  final img.Image canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  img.fillCircle(
    canvas,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: size ~/ 2 - 4,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  img.fillCircle(
    canvas,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: size ~/ 2 - 16,
    color: img.ColorRgba8(26, 61, 124, 255),
  );
  img.fillCircle(
    canvas,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: size ~/ 2 - 30,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  // Open-book glyph.
  img.fillRect(
    canvas,
    x1: 70,
    y1: 100,
    x2: 116,
    y2: 150,
    color: img.ColorRgba8(26, 61, 124, 255),
  );
  img.fillRect(
    canvas,
    x1: 124,
    y1: 100,
    x2: 170,
    y2: 150,
    color: img.ColorRgba8(26, 61, 124, 255),
  );

  return img.encodePng(canvas);
}
