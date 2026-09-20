import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/features/card_render/domain/card_typography.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// How much the card has to shrink to hold the enabled fields.
///
/// The renderer silently scales every row down when the field block cannot
/// hold them at their specified point sizes, so a field switched on in the
/// admin panel can quietly cost print legibility with nothing on screen to say
/// so. No render test populated a roll number before this file - blank fields
/// are filtered out before layout - so the extra row had never been laid out.
///
/// These tests pin the measured fit per template. They are a tripwire: if a
/// change makes a card shrink further, the number here fails rather than the
/// difference showing up on paper at a school.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Measured fit scale with every field enabled and populated, per template.
  ///
  /// 0.600 is `_minimumFitScale`, the hard floor - a template sitting on it is
  /// already clamped and has no room left. Three of these were on or near the
  /// floor before roll number existed; that is a template-geometry problem
  /// (the field blocks are too short for nine rows), not a roll number one,
  /// and it needs the client's real card artwork to resolve properly.
  const Map<String, ({double withoutRoll, double withRoll})> expected =
      <String, ({double withoutRoll, double withRoll})>{
        'default_vertical.json': (withoutRoll: 0.685, withRoll: 0.600),
        'default_horizontal.json': (withoutRoll: 1.000, withRoll: 1.000),
        'div_badge_vertical.json': (withoutRoll: 0.600, withRoll: 0.600),
        'side_panel_horizontal.json': (withoutRoll: 1.000, withRoll: 1.000),
        'framed_vertical.json': (withoutRoll: 0.600, withRoll: 0.600),
      };

  Future<CardTemplate> load(String name) async {
    final String raw = await rootBundle.loadString('assets/templates/$name');
    return CardTemplate.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  StudentEntry entry({String rollNumber = ''}) => StudentEntry(
    id: 'e1',
    schoolId: 's1',
    name: 'RAMESH KUMAR PATIL',
    fatherName: 'SURESH KUMAR PATIL',
    studentClass: '10',
    division: 'A',
    rollNumber: rollNumber,
    bloodGroup: 'O+',
    dob: DateTime(2012, 4, 17),
    mobile: '9876543210',
    address: '12/A, MG ROAD, HUBLI - 580020',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<CardRenderPlan> plan(String name, {required bool withRoll}) async =>
      IdCardRenderer.planFor(
        entry: entry(rollNumber: withRoll ? '12/A' : ''),
        config: SchoolConfig(
          id: 's1',
          name: 'ST JOHN SAMARITAN SCHOOL',
          addressLine: 'ANAND NAGAR, HUBBALLI - 580025',
          contactLine: 'Office: 0836-2345678',
          enabledFieldKeys: SchoolConfig.allFieldKeys,
        ),
        template: await load(name),
        size: CardSize.v54x86,
      );

  group('Typography is declared, never inherited', () {
    test('every printable field has its own entry', () {
      for (final StudentField f in StudentField.printableRows) {
        expect(
          CardTypography.byField.containsKey(f),
          isTrue,
          reason:
              '${f.key} has no declared style, so it silently falls through '
              'to the ?? default - a size nobody chose',
        );
      }
    });

    test('roll number is a supporting row, like mobile', () {
      final CardTypography roll =
          CardTypography.byField[StudentField.rollNumber]!;
      expect(roll.sizePt, 7);
      expect(roll.bold, isFalse);
      expect(
        roll.sizePt,
        CardTypography.byField[StudentField.mobile]!.sizePt,
        reason: 'both are secondary identifiers and should read alike',
      );
    });
  });

  group('Roll number reaches the card', () {
    test('the row is laid out once it has a value', () async {
      final CardRenderPlan p = await plan(
        'default_vertical.json',
        withRoll: true,
      );
      expect(
        p.rows.map((PlannedRow r) => r.field),
        contains(StudentField.rollNumber),
      );
    });

    test('a blank roll number prints nothing', () async {
      final CardRenderPlan p = await plan(
        'default_vertical.json',
        withRoll: false,
      );
      expect(
        p.rows.map((PlannedRow r) => r.field),
        isNot(contains(StudentField.rollNumber)),
        reason: 'an empty "ROLL NO :" label would look like a defect',
      );
    });

    test('it adds exactly one row to every template', () async {
      for (final String name in expected.keys) {
        final CardRenderPlan without = await plan(name, withRoll: false);
        final CardRenderPlan with9 = await plan(name, withRoll: true);
        expect(with9.rows.length, without.rows.length + 1, reason: name);
      }
    });
  });

  group('Measured fit per template', () {
    test('matches the recorded baseline', () async {
      for (final MapEntry<String, ({double withoutRoll, double withRoll})> e
          in expected.entries) {
        final CardRenderPlan without = await plan(e.key, withRoll: false);
        final CardRenderPlan with9 = await plan(e.key, withRoll: true);

        expect(
          without.fitScale,
          closeTo(e.value.withoutRoll, 0.005),
          reason: '${e.key} without roll number',
        );
        expect(
          with9.fitScale,
          closeTo(e.value.withRoll, 0.005),
          reason: '${e.key} with roll number',
        );
      }
    });

    test('a template that has to shrink says so', () async {
      for (final String name in expected.keys) {
        final CardRenderPlan p = await plan(name, withRoll: true);
        final bool shrinks = p.fitScale < 1.0;
        expect(
          p.warnings.isNotEmpty,
          shrinks,
          reason: shrinks
              ? '$name shrinks to ${p.fitScale} but produced no warning, so '
                    'the admin has nothing telling them the card lost legibility'
              : '$name fits but warned anyway',
        );
      }
    });

    test(
      'the two horizontal templates hold every field at full size',
      () async {
        for (final String name in <String>[
          'default_horizontal.json',
          'side_panel_horizontal.json',
        ]) {
          final CardRenderPlan p = await plan(name, withRoll: true);
          expect(p.fitScale, 1.0, reason: name);
          expect(p.warnings, isEmpty, reason: name);

          // Spot-check that the declared sizes survive untouched.
          final PlannedRow address = p.rows.firstWhere(
            (PlannedRow r) => r.field == StudentField.address,
          );
          expect(address.style.sizePt, closeTo(5, 0.001));
        }
      },
    );

    test('nothing is ever planned below the floor', () async {
      for (final String name in expected.keys) {
        final CardRenderPlan p = await plan(name, withRoll: true);
        expect(
          p.fitScale,
          greaterThanOrEqualTo(0.6),
          reason: '$name went under the clamp',
        );
      }
    });
  });

  group('The estimate the admin panel shows', () {
    // School settings now tells an admin what switching a field on costs,
    // using `estimateFit`. The number it shows has to be the number the
    // renderer will actually use - a warning that disagrees with the output is
    // worse than no warning, because it trains people to ignore it.

    test('agrees with the renderer, template for template', () async {
      for (final String name in expected.keys) {
        final CardTemplate template = await load(name);
        final CardRenderPlan planned = await plan(name, withRoll: true);

        final CardFit estimated = IdCardRenderer.estimateFit(
          template: template,
          size: CardSize.defaultSize,
          fields: StudentField.values,
        );

        expect(
          estimated.scale,
          closeTo(planned.fitScale, 0.0001),
          reason:
              '$name: settings would promise a different size than the '
              'renderer produces',
        );
      }
    });

    test('flags the three templates that are on the floor', () async {
      // The actual state of the bundled artwork, and the reason this readout
      // exists: with every field on, three of five cards print their smaller
      // rows at roughly three points.
      for (final String name in <String>[
        'default_vertical.json',
        'div_badge_vertical.json',
        'framed_vertical.json',
      ]) {
        final CardFit fit = IdCardRenderer.estimateFit(
          template: await load(name),
          size: CardSize.defaultSize,
          fields: StudentField.values,
        );
        expect(fit.isClamped, isTrue, reason: name);
        expect(fit.warning, isNotNull, reason: name);
        expect(fit.isComfortable, isFalse, reason: name);
      }
    });

    test('says nothing when there is nothing to say', () async {
      for (final String name in <String>[
        'default_horizontal.json',
        'side_panel_horizontal.json',
      ]) {
        final CardFit fit = IdCardRenderer.estimateFit(
          template: await load(name),
          size: CardSize.defaultSize,
          fields: StudentField.values,
        );
        expect(fit.isComfortable, isTrue, reason: name);
        expect(fit.warning, isNull, reason: name);
        expect(fit.percent, 100, reason: name);
      }
    });

    test('improves as fields are switched off', () async {
      // The whole point of showing it: the admin can act on it.
      final CardTemplate template = await load('default_vertical.json');

      final CardFit all = IdCardRenderer.estimateFit(
        template: template,
        size: CardSize.defaultSize,
        fields: StudentField.values,
      );
      final CardFit fewer = IdCardRenderer.estimateFit(
        template: template,
        size: CardSize.defaultSize,
        fields: StudentField.values
            .where(
              (StudentField f) =>
                  f != StudentField.address &&
                  f != StudentField.mobile &&
                  f != StudentField.bloodGroup,
            )
            .toList(),
      );

      expect(fewer.scale, greaterThan(all.scale));
      expect(fewer.fieldCount, lessThan(all.fieldCount));
    });

    test('an empty field list is not a divide by zero', () async {
      final CardFit fit = IdCardRenderer.estimateFit(
        template: await load('default_vertical.json'),
        size: CardSize.defaultSize,
        fields: const <StudentField>[],
      );
      expect(fit.scale, 1.0);
      expect(fit.warning, isNull);
    });
  });
}
