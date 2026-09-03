import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/features/card_render/domain/card_typography.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

StudentEntry sampleEntry({
  String name = 'RAMESH KUMAR PATIL',
  String address = '12/A, MG ROAD, HUBLI - 580020',
}) {
  return StudentEntry(
    id: 'e1',
    schoolId: 's1',
    name: name,
    fatherName: 'SURESH KUMAR PATIL',
    studentClass: '10',
    division: 'A',
    bloodGroup: 'O+',
    dob: DateTime(2012, 4, 17),
    mobile: '9876543210',
    address: address,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

SchoolConfig sampleConfig({Set<String>? fields, String templateId = 'default_vertical'}) {
  return SchoolConfig(
    id: 's1',
    name: 'ST JOHN SAMARITAN SCHOOL',
    addressLine: 'ANAND NAGAR, HUBBALLI - 580025',
    contactLine: 'Office: 0836-2345678',
    templateId: templateId,
    enabledFieldKeys: fields ?? SchoolConfig.allFieldKeys,
  );
}

Future<CardTemplate> loadTemplate(String asset) async {
  final String raw = await rootBundle.loadString(asset);
  return CardTemplate.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

/// Every template that ships in the bundle. The structural checks below run
/// against all of them, so adding a template automatically inherits the
/// photo-size, bounds and parse guarantees.
const List<String> kAllTemplateAssets = <String>[
  'assets/templates/default_vertical.json',
  'assets/templates/default_horizontal.json',
  'assets/templates/div_badge_vertical.json',
  'assets/templates/side_panel_horizontal.json',
  'assets/templates/framed_vertical.json',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('page geometry - the physical size guarantee', () {
    test('a 54x86 mm card produces a 54x86 mm page', () {
      final PdfPageFormat format = IdCardRenderer.pageFormatFor(CardSize.v54x86);

      expect(PrintUnits.ptToMm(format.width), closeTo(54, 1e-9));
      expect(PrintUnits.ptToMm(format.height), closeTo(86, 1e-9));
    });

    test('every supported size round-trips to its exact millimetres', () {
      for (final CardSize size in CardSize.all) {
        final PdfPageFormat format = IdCardRenderer.pageFormatFor(size);
        expect(
          PrintUnits.ptToMm(format.width),
          closeTo(size.widthMm, 1e-9),
          reason: size.id,
        );
        expect(
          PrintUnits.ptToMm(format.height),
          closeTo(size.heightMm, 1e-9),
          reason: size.id,
        );
      }
    });

    test('page margins are zero - any margin would shrink the card', () {
      final PdfPageFormat format = IdCardRenderer.pageFormatFor(CardSize.v54x86);
      expect(format.marginLeft, 0);
      expect(format.marginTop, 0);
      expect(format.marginRight, 0);
      expect(format.marginBottom, 0);
      expect(format.availableWidth, format.width);
      expect(format.availableHeight, format.height);
    });

    test('3 mm bleed grows the page by 6 mm on each axis, not 3', () {
      final PdfPageFormat format =
          IdCardRenderer.pageFormatFor(CardSize.v54x86, bleedMm: 3);
      expect(PrintUnits.ptToMm(format.width), closeTo(60, 1e-9));
      expect(PrintUnits.ptToMm(format.height), closeTo(92, 1e-9));
    });
  });

  group('generated PDF', () {
    test('declares a MediaBox of exactly the card size in points', () async {
      final IdCardRenderer renderer = await IdCardRenderer.load();
      final CardTemplate template =
          await loadTemplate('assets/templates/default_vertical.json');

      final Uint8List bytes = await renderer.buildSingleCardPdf(
        entry: sampleEntry(),
        config: sampleConfig(),
        template: template,
        size: CardSize.v54x86,
        // Uncompressed so the page dictionary is readable in the raw bytes.
        compress: false,
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      final String content = latin1.decode(bytes, allowInvalid: true);
      final RegExpMatch? box =
          RegExp(r'/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\]')
              .firstMatch(content);

      expect(box, isNotNull, reason: 'no /MediaBox found in the generated PDF');

      final double widthPt = double.parse(box!.group(3)!);
      final double heightPt = double.parse(box.group(4)!);

      // 0.01 pt is 3.5 microns - far below what any printer or ruler resolves.
      expect(PrintUnits.ptToMm(widthPt), closeTo(54, 0.01));
      expect(PrintUnits.ptToMm(heightPt), closeTo(86, 0.01));
    });

    test('renders a horizontal card at 86x54 mm', () async {
      final IdCardRenderer renderer = await IdCardRenderer.load();
      final CardTemplate template =
          await loadTemplate('assets/templates/default_horizontal.json');

      final Uint8List bytes = await renderer.buildSingleCardPdf(
        entry: sampleEntry(),
        config: sampleConfig(templateId: 'default_horizontal'),
        template: template,
        size: CardSize.h86x54,
        compress: false,
      );

      final String content = latin1.decode(bytes, allowInvalid: true);
      final RegExpMatch? box =
          RegExp(r'/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\]')
              .firstMatch(content);

      expect(PrintUnits.ptToMm(double.parse(box!.group(3)!)), closeTo(86, 0.01));
      expect(PrintUnits.ptToMm(double.parse(box.group(4)!)), closeTo(54, 0.01));
    });

    test('a card with no photo still produces a valid PDF', () async {
      // Operators do occasionally save before the photo lands; the renderer
      // must not throw on the print path.
      final IdCardRenderer renderer = await IdCardRenderer.load();
      final CardTemplate template =
          await loadTemplate('assets/templates/default_vertical.json');

      final Uint8List bytes = await renderer.buildSingleCardPdf(
        entry: sampleEntry(),
        config: sampleConfig(),
        template: template,
        size: CardSize.v54x86,
      );
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('templates parse', () {
    test('the bundled vertical template loads and is authored for 54x86', () async {
      final CardTemplate template =
          await loadTemplate('assets/templates/default_vertical.json');
      expect(template.id, 'default_vertical');
      expect(template.authoredSize, CardSize.v54x86);
      expect(template.orientation, CardOrientation.vertical);
      expect(template.elements, isNotEmpty);
    });

    test('the bundled horizontal template loads and is authored for 86x54', () async {
      final CardTemplate template =
          await loadTemplate('assets/templates/default_horizontal.json');
      expect(template.authoredSize, CardSize.h86x54);
      expect(template.orientation, CardOrientation.horizontal);
    });

    test('every template reserves a photo box of exactly 1.2 x 1.5 inch', () async {
      for (final String asset in kAllTemplateAssets) {
        final CardTemplate template = await loadTemplate(asset);
        final PhotoElement photo =
            template.elements.whereType<PhotoElement>().single;

        expect(photo.widthMm, closeTo(PhotoSpec.widthMm, 1e-6), reason: asset);
        expect(photo.heightMm, closeTo(PhotoSpec.heightMm, 1e-6), reason: asset);
      }
    });

    test('every element stays inside the card it is authored for', () async {
      for (final String asset in kAllTemplateAssets) {
        final CardTemplate template = await loadTemplate(asset);
        final CardSize size = template.authoredSize;

        for (final CardElement e in template.elements) {
          expect(
            e.xMm + e.widthMm,
            lessThanOrEqualTo(size.widthMm + 1e-6),
            reason: '$asset: ${e.runtimeType} overflows the right edge',
          );
          expect(
            e.yMm + e.heightMm,
            lessThanOrEqualTo(size.heightMm + 1e-6),
            reason: '$asset: ${e.runtimeType} overflows the bottom edge',
          );
          expect(e.xMm, greaterThanOrEqualTo(-1e-6), reason: asset);
          expect(e.yMm, greaterThanOrEqualTo(-1e-6), reason: asset);
        }
      }
    });

    test('all five bundled templates load and are internally consistent',
        () async {
      for (final String asset in kAllTemplateAssets) {
        final CardTemplate template = await loadTemplate(asset);
        expect(template.elements, isNotEmpty, reason: asset);
        // Exactly one photo slot and one field block per template - two of
        // either would silently draw the same content twice.
        expect(
          template.elements.whereType<PhotoElement>().length,
          1,
          reason: asset,
        );
        expect(
          template.elements.whereType<FieldBlockElement>().length,
          1,
          reason: asset,
        );
      }
    });

    test('the division badge is gated on the division field', () async {
      final CardTemplate template =
          await loadTemplate('assets/templates/div_badge_vertical.json');
      final TextElement badge = template.elements
          .whereType<TextElement>()
          .firstWhere((TextElement e) => e.value.contains('{division}'));

      expect(badge.requiresFieldKey, 'division');
      // Present for a student who has a division...
      expect(badge.appliesTo(sampleEntry()), isTrue);
      // ...and dropped entirely for one who does not, rather than printing
      // a bare "DIV-".
      expect(
        badge.appliesTo(sampleEntry().copyWith(division: '')),
        isFalse,
      );
    });

    test('student tokens are substituted into static text', () async {
      final CardTemplate template =
          await loadTemplate('assets/templates/div_badge_vertical.json');
      final TextElement badge = template.elements
          .whereType<TextElement>()
          .firstWhere((TextElement e) => e.value.contains('{division}'));

      expect(badge.resolve(sampleConfig(), sampleEntry()), 'DIV-A');
      expect(
        badge.resolve(sampleConfig(), sampleEntry().copyWith(division: 'F')),
        'DIV-F',
      );
    });

    test('school tokens still resolve with no entry', () async {
      final CardTemplate template =
          await loadTemplate('assets/templates/default_vertical.json');
      final TextElement title = template.elements
          .whereType<TextElement>()
          .firstWhere((TextElement e) => e.value.contains('{schoolName}'));

      expect(
        title.resolve(sampleConfig(), null),
        contains('ST JOHN SAMARITAN'),
      );
    });

    test('unknown element types are skipped, not fatal', () {
      final CardTemplate template = CardTemplate.fromJson(<String, Object?>{
        'id': 't',
        'name': 'T',
        'cardSizeId': 'v54x86',
        'elements': <Object?>[
          <String, Object?>{'type': 'somethingFromTheFuture', 'x': 0, 'y': 0},
          <String, Object?>{'type': 'rect', 'x': 0, 'y': 0, 'w': 10, 'h': 10},
        ],
      });
      expect(template.elements.length, 1);
      expect(template.elements.single, isA<RectElement>());
    });
  });

  group('ColorRef', () {
    final SchoolConfig config = sampleConfig().copyWith(
      primaryColorHex: 0xFFAA0000,
      secondaryColorHex: 0xFF0000BB,
      headerColorHex: 0xFF00CC00,
    );
    final CardPalette palette = CardPalette(config: config);

    test('tokens resolve against the school palette', () {
      expect(
        const ColorRef.token(ColorToken.primary).resolve(palette),
        0xFFAA0000,
      );
      expect(
        const ColorRef.token(ColorToken.secondary).resolve(palette),
        0xFF0000BB,
      );
    });

    test('literals are used as-is', () {
      expect(ColorRef.parse('#123456').resolve(palette), 0xFF123456);
    });

    test('a typo falls back instead of throwing', () {
      expect(ColorRef.parse('#ZZZ').resolve(palette), 0xFFFFFFFF);
    });

    test('header falls back to the school colour with no division colours', () {
      expect(
        const ColorRef.token(ColorToken.header).resolve(palette),
        0xFF00CC00,
      );
      expect(
        const ColorRef.token(ColorToken.divAccent)
            .resolve(CardPalette(config: config, division: 'A')),
        0xFF00CC00,
      );
    });
  });

  group('per-division colours', () {
    final SchoolConfig config = sampleConfig().copyWith(
      headerColorHex: 0xFF00CC00,
      divisionColors: <String, int>{
        'A': 0xFFFF0000,
        'B': 0xFF0000FF,
        'C': 0xFFFF69B4,
      },
    );

    int headerFor(String division) =>
        const ColorRef.token(ColorToken.header)
            .resolve(CardPalette(config: config, division: division));

    test('each division gets its own accent colour', () {
      expect(headerFor('A'), 0xFFFF0000);
      expect(headerFor('B'), 0xFF0000FF);
      expect(headerFor('C'), 0xFFFF69B4);
    });

    test('divAccent is an alias for header, not a separate colour', () {
      final CardPalette p = CardPalette(config: config, division: 'B');
      expect(
        const ColorRef.token(ColorToken.divAccent).resolve(p),
        const ColorRef.token(ColorToken.header).resolve(p),
      );
    });

    test('an unlisted division falls back to the school colour', () {
      expect(headerFor('Z'), 0xFF00CC00);
    });

    test('a blank division falls back to the school colour', () {
      expect(headerFor(''), 0xFF00CC00);
      expect(headerFor('   '), 0xFF00CC00);
    });

    test('lookup ignores case and stray whitespace from the operator', () {
      // Division is a free-text field - "a", "A" and " A " are the same class.
      expect(headerFor('a'), 0xFFFF0000);
      expect(headerFor(' a '), 0xFFFF0000);
    });

    test('primary and secondary are unaffected by division', () {
      final CardPalette p = CardPalette(config: config, division: 'A');
      expect(p.primary, config.primaryColorHex);
      expect(p.secondary, config.secondaryColorHex);
    });

    test('withDivisionColor sets and clears one division', () {
      final SchoolConfig added =
          config.withDivisionColor('d', 0xFF00FF00);
      expect(added.headerColorFor('D'), 0xFF00FF00);

      final SchoolConfig removed = added.withDivisionColor('D', null);
      expect(removed.headerColorFor('D'), 0xFF00CC00);
      // Removing one must not disturb the others.
      expect(removed.headerColorFor('A'), 0xFFFF0000);
    });

    test('survives a Firestore round-trip', () {
      final SchoolConfig restored = SchoolConfig.fromFirestoreMap(
        's1',
        config.toFirestoreMap(),
      );
      expect(restored.headerColorFor('A'), 0xFFFF0000);
      expect(restored.headerColorFor('B'), 0xFF0000FF);
      expect(restored.usesDivisionColors, isTrue);
    });

    test('a malformed colour in the console is skipped, not fatal', () {
      final Map<String, int> decoded = SchoolConfig.decodeDivisionColors(
        <String, Object?>{'A': '#FF0000', 'B': 'not-a-colour', 'C': 42},
      );
      expect(decoded, <String, int>{'A': 0xFFFF0000});
    });
  });

  group('layout planning', () {
    Future<CardRenderPlan> plan({
      Set<String>? fields,
      StudentEntry? entry,
      CardSize size = CardSize.v54x86,
      String asset = 'assets/templates/default_vertical.json',
    }) async {
      return IdCardRenderer.planFor(
        entry: entry ?? sampleEntry(),
        config: sampleConfig(fields: fields),
        template: await loadTemplate(asset),
        size: size,
      );
    }

    test('skips fields the school has switched off', () async {
      final CardRenderPlan p = await plan(
        fields: <String>{'name', 'photo', 'dob', 'mobile'},
      );
      final Set<StudentField> drawn =
          p.rows.map((PlannedRow r) => r.field).toSet();

      expect(drawn, <StudentField>{StudentField.dob, StudentField.mobile});
      expect(drawn, isNot(contains(StudentField.bloodGroup)));
    });

    test('skips the name row - it has its own banner element', () async {
      final CardRenderPlan p = await plan();
      expect(
        p.rows.map((PlannedRow r) => r.field),
        isNot(contains(StudentField.name)),
      );
    });

    test('skips enabled fields that have no value', () async {
      // An empty "MOBILE NO :" row reads as a defect on a printed card.
      final CardRenderPlan p = await plan(
        entry: sampleEntry().copyWith(mobile: ''),
      );
      expect(
        p.rows.map((PlannedRow r) => r.field),
        isNot(contains(StudentField.mobile)),
      );
    });

    test('prints at full specified size when few fields are enabled', () async {
      final CardRenderPlan p = await plan(
        fields: <String>{'name', 'photo', 'fatherName', 'dob', 'mobile'},
      );
      expect(p.fitScale, 1.0);
      expect(p.hasWarnings, isFalse);

      final PlannedRow dob =
          p.rows.firstWhere((PlannedRow r) => r.field == StudentField.dob);
      expect(dob.style.sizePt, CardTypography.byField[StudentField.dob]!.sizePt);
    });

    test('rows never overflow the field block', () async {
      final CardRenderPlan p = await plan();
      final CardTemplate template =
          await loadTemplate('assets/templates/default_vertical.json');
      final FieldBlockElement block =
          template.elements.whereType<FieldBlockElement>().single;

      double used = 0;
      for (final PlannedRow r in p.rows) {
        used += r.heightMm;
      }
      used += block.rowGapMm * (p.rows.length - 1).clamp(0, 100);

      expect(
        used,
        lessThanOrEqualTo(block.heightMm + 1e-6),
        reason: 'flowed rows must fit inside the reserved block',
      );
    });

    test('warns rather than silently shrinking when everything is enabled',
        () async {
      final CardRenderPlan p = await plan();
      // With all eight fields on a 54x86 card the block is genuinely tight.
      // Whatever the outcome, scale and warning must agree with each other.
      if (p.fitScale < 0.92) {
        expect(p.hasWarnings, isTrue);
        expect(p.warnings.single, contains('admin panel'));
      } else {
        expect(p.hasWarnings, isFalse);
      }
      expect(p.fitScale, greaterThan(0));
      expect(p.fitScale, lessThanOrEqualTo(1.0));
    });

    test('the horizontal template has room for every field at full size',
        () async {
      final CardRenderPlan p = await plan(
        asset: 'assets/templates/default_horizontal.json',
        size: CardSize.h86x54,
      );
      expect(p.fitScale, 1.0, reason: 'the wide layout has a 31 mm field block');
      expect(p.hasWarnings, isFalse);
    });

    test('address is planned as a two-line row', () async {
      final CardRenderPlan p = await plan();
      final PlannedRow address =
          p.rows.firstWhere((PlannedRow r) => r.field == StudentField.address);
      expect(address.style.maxLines, 2);
      // A two-line row must be taller than a one-line row of the same size.
      expect(
        address.heightMm,
        greaterThan(PrintUnits.ptToMm(address.style.sizePt * 1.18)),
      );
    });
  });
}
