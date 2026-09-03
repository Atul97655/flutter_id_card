import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outDir;
  late File photoFile;
  late File logoFile;

  setUpAll(() {
    // Written under build/, like sample_card_generation_test.dart, rather than
    // into a real user folder - a test run must not leave files scattered
    // outside the repo, and must produce the same result on any machine.
    outDir = Directory('build/generated_school_cards')..createSync(recursive: true);

    // Generate synthetic images
    final img.Image canvas = img.Image(width: 360, height: 450);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.fillCircle(canvas, x: 180, y: 460, radius: 187, color: img.ColorRgb8(150, 165, 185));
    img.fillRect(canvas, x1: 140, y1: 234, x2: 220, y2: 360, color: img.ColorRgb8(196, 168, 148));
    img.fillCircle(canvas, x: 180, y: 180, radius: 100, color: img.ColorRgb8(212, 182, 160));
    img.fillCircle(canvas, x: 180, y: 135, radius: 97, color: img.ColorRgb8(58, 44, 38));
    img.fillRect(canvas, x1: 83, y1: 117, x2: 277, y2: 162, color: img.ColorRgb8(58, 44, 38));
    img.fillCircle(canvas, x: 180, y: 180, radius: 84, color: img.ColorRgb8(212, 182, 160));

    photoFile = File('${outDir.path}/temp_photo.png')
      ..writeAsBytesSync(img.encodePng(canvas));

    final img.Image logoCanvas = img.Image(width: 240, height: 240);
    img.fill(logoCanvas, color: img.ColorRgb8(255, 255, 255));
    img.fillCircle(logoCanvas, x: 120, y: 120, radius: 100, color: img.ColorRgb8(26, 61, 124));
    img.fillCircle(logoCanvas, x: 120, y: 120, radius: 80, color: img.ColorRgb8(255, 255, 255));
    logoFile = File('${outDir.path}/temp_logo.png')
      ..writeAsBytesSync(img.encodePng(logoCanvas));
  });

  tearDownAll(() {
    try {
      if (photoFile.existsSync()) photoFile.deleteSync();
      if (logoFile.existsSync()) logoFile.deleteSync();
    } catch (_) {}
  });

  test('generates a sample card for every reference school design', () async {
    final IdCardRenderer renderer = await IdCardRenderer.load();

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

    final List<Map<String, String>> schools = [
      {
        'name': '7TH DAY SCHOOL',
        'address': 'BAVANI NAGAR, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'AIN COLLEGE',
        'address': 'HEBBALLI ROAD, HUBLI',
        'template': 'default_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'ALL SAINTS SCHOOL',
        'address': 'BHAIRIDEVARKOPPA, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'CIM COLLEGE',
        'address': 'DHARWAD',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'GOVT PU COLLEGE',
        'address': 'BHAMMIGATTI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'GOVT. PU COLLEGE',
        'address': 'SANGMESHWAR',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'ICS INSTITUTE',
        'address': 'DHARWAD',
        'template': 'default_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'JACK AND JILL SCHOOL',
        'address': 'RAVI NAGAR, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'JAIN COLLEGE',
        'address': 'HEBBALLI ROAD, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'JACOB SCHOOL',
        'address': 'GADAG ROAD, HUBLI',
        'template': 'framed_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'JSS SCHOOL',
        'address': 'GADAG',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'KH PATIL COLLEGE',
        'address': 'HUBLI',
        'template': 'default_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'MEDHA COLLEGE',
        'address': 'HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'MOTHER TERESA SCHOOL',
        'address': 'ANAND NAGAR, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'NALANDA COLLEGE',
        'address': 'GADAG ROAD, HUBLI',
        'template': 'default_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'PARIVARTANA COLLEGE',
        'address': 'GOPANKOPPA, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'PRATHIBA VIKAS SCHOOL',
        'address': 'GURUNATH NAGAR, HUBLI',
        'template': 'framed_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'SHARADHA SCHOOL',
        'address': 'DHARWAD',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'SR SCHOOL',
        'address': 'KESHAVAPUR, HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'ST. HAMZA SCHOOL',
        'address': 'HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'ST. JOHN SAMARITAN SCHOOL',
        'address': 'ANAND NAGAR, HUBLI',
        'template': 'side_panel_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'ST. JOHN SAMARITAN SCHOOL',
        'address': 'NEKAR NAGAR, HUBLI',
        'template': 'side_panel_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'SUJNAN SCHOOL',
        'address': 'HUBLI',
        'template': 'default_horizontal',
        'orientation': 'horizontal'
      },
      {
        'name': 'TAPASYA SCHOOL',
        'address': 'HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      },
      {
        'name': 'VIDYADARSHINI SCHOOL',
        'address': 'HUBLI',
        'template': 'default_vertical',
        'orientation': 'vertical'
      }
    ];

    // Two entries share the school name "ST. JOHN SAMARITAN SCHOOL" (different
    // towns), so the filename cannot be built from the name alone - that would
    // make the second write silently overwrite the first one's PDF on disk.
    // Track names already used and suffix a collision, the same pattern
    // ImpositionService.buildSingleCards uses for the same class of problem.
    final Set<String> usedFilenames = <String>{};
    int generatedCount = 0;

    for (final Map<String, String> school in schools) {
      final String name = school['name']!;
      final String address = school['address']!;
      final String templateId = school['template']!;
      final String orientation = school['orientation']!;

      final CardSize size = orientation == 'horizontal' ? CardSize.h86x54 : CardSize.v54x86;
      final CardTemplate template = await _template('assets/templates/$templateId.json');

      final SchoolConfig config = SchoolConfig(
        id: name.toLowerCase().replaceAll(' ', '_'),
        name: name,
        addressLine: address,
        contactLine: 'Mob: 9876543210   |   Email: info@${name.toLowerCase().replaceAll(' ', '')}.edu.in',
        localLogoPath: logoFile.path,
        enabledFieldKeys: SchoolConfig.allFieldKeys,
      );

      final String baseName = '${name.replaceAll(' ', '_')}_$orientation';
      String filename = '$baseName.pdf';
      int suffix = 2;
      while (usedFilenames.contains(filename.toLowerCase())) {
        filename = '${baseName}_$suffix.pdf';
        suffix++;
      }
      usedFilenames.add(filename.toLowerCase());

      final Uint8List pdfBytes = await renderer.buildSingleCardPdf(
        entry: entry,
        config: config,
        template: template,
        size: size,
      );

      await File('${outDir.path}/$filename').writeAsBytes(pdfBytes);
      generatedCount++;
    }

    // Sacred Heart Convent division cards
    const Map<String, int> divisionPalette = <String, int>{
      'A': 0xFFE01B1B, // red
      'B': 0xFF1A1AE0, // blue
      'C': 0xFFE0189C, // pink
      'D': 0xFF14A05A, // green
      'E': 0xFFF07A16, // orange
      'F': 0xFF7B1FA2, // purple
    };

    final SchoolConfig conventConfig = SchoolConfig(
      id: 'sacred_heart_convent',
      name: 'SACRED HEART CONVENT',
      addressLine: 'PRE-PRIMARY SCHOOL, KESHWAPUR HUBBALLI',
      contactLine: 'Mob: 9538848187',
      localLogoPath: logoFile.path,
      templateId: 'div_badge_vertical',
      divisionColors: divisionPalette,
      enabledFieldKeys: <String>{'name', 'photo', 'division', 'mobile', 'address'},
    );

    final CardTemplate divTemplate = await _template('assets/templates/div_badge_vertical.json');

    for (final String division in divisionPalette.keys) {
      final String filename = 'SACRED_HEART_CONVENT_DIV_$division.pdf';
      final Uint8List pdfBytes = await renderer.buildSingleCardPdf(
        entry: entry.copyWith(division: division),
        config: conventConfig,
        template: divTemplate,
        size: CardSize.v54x86,
      );

      await File('${outDir.path}/$filename').writeAsBytes(pdfBytes);
      generatedCount++;
    }

    // 25 schools + 6 division cards. Asserted rather than printed, so a
    // silently-dropped card (e.g. the overwrite bug this file used to have)
    // fails the test instead of scrolling past in console output.
    expect(generatedCount, schools.length + divisionPalette.length);
    final int pdfFilesOnDisk = outDir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.pdf'))
        .length;
    expect(pdfFilesOnDisk, generatedCount);
  });
}

Future<CardTemplate> _template(String asset) async {
  final String raw = await rootBundle.loadString(asset);
  return CardTemplate.fromJson(jsonDecode(raw) as Map<String, Object?>);
}
