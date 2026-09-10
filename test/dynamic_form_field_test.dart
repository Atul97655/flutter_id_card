import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/presentation/widgets/dynamic_form_field.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one widget every field on the entry form goes through.
///
/// It had no tests, despite carrying the auto-CAPITAL rule the card
/// specification depends on and the Class/Division dropdowns the plan asks
/// for - a claim that had only ever been checked by reading the source.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required StudentField field,
    required TextEditingController controller,
    List<String>? options,
    DateTime? selectedDate,
    ValueChanged<DateTime?>? onDateChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Form(
            child: DynamicFormField(
              field: field,
              controller: controller,
              options: options,
              selectedDate: selectedDate,
              onDateChanged: onDateChanged ?? (DateTime? _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Class and Division render as dropdowns', () {
    testWidgets('Class offers the school list, not a free text box', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(
        tester,
        field: StudentField.studentClass,
        controller: c,
        options: const <String>['NURSERY', 'LKG', '1', '2'],
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('picking a class writes it back to the controller', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(
        tester,
        field: StudentField.studentClass,
        controller: c,
        options: const <String>['NURSERY', 'LKG', '1'],
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LKG').last);
      await tester.pumpAndSettle();

      expect(c.text, 'LKG');
    });

    testWidgets('Division offers its own list', (WidgetTester tester) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(
        tester,
        field: StudentField.division,
        controller: c,
        options: const <String>['A', 'B', 'C'],
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('a value already saved but no longer offered is kept', (
      WidgetTester tester,
    ) async {
      // A school can edit its class list. An entry captured under the old list
      // must not silently lose its class when the form reopens.
      final TextEditingController c = TextEditingController(text: 'PRE-KG');
      addTearDown(c.dispose);

      await pump(
        tester,
        field: StudentField.studentClass,
        controller: c,
        options: const <String>['LKG', 'UKG'],
      );

      expect(find.text('PRE-KG'), findsOneWidget);
      expect(c.text, 'PRE-KG');
    });

    testWidgets('an empty option list falls back to a text box', (
      WidgetTester tester,
    ) async {
      // A school with no configured classes must still be able to take entries.
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(
        tester,
        field: StudentField.studentClass,
        controller: c,
        options: const <String>[],
      );

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('Roll number', () {
    testWidgets('is a free text box - registers are not a fixed list', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.rollNumber, controller: c);

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Roll No'), findsOneWidget);
    });

    testWidgets('forces capitals, so 12/a is stored as 12/A', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.rollNumber, controller: c);
      await tester.enterText(find.byType(TextFormField), '12/a');
      await tester.pump();

      expect(
        c.text,
        '12/A',
        reason: 'the Firestore rules reject lowercase card text outright',
      );
    });
  });

  group('Auto-capitalisation', () {
    testWidgets('applies to every field the card prints in capitals', (
      WidgetTester tester,
    ) async {
      for (final StudentField f in StudentField.values.where(
        (StudentField f) => f.forceUppercase && f.kind != FieldKind.multiline,
      )) {
        final TextEditingController c = TextEditingController();
        await pump(tester, field: f, controller: c);
        await tester.enterText(find.byType(TextFormField), 'lower case');
        await tester.pump();

        expect(c.text, 'LOWER CASE', reason: f.key);
        c.dispose();
      }
    });

    testWidgets('collapses runs of whitespace', (WidgetTester tester) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.name, controller: c);
      await tester.enterText(find.byType(TextFormField), 'RAMESH    KUMAR');
      await tester.pump();

      expect(c.text, 'RAMESH KUMAR');
    });
  });

  group('Mobile', () {
    testWidgets('accepts digits only', (WidgetTester tester) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.mobile, controller: c);
      await tester.enterText(find.byType(TextFormField), '98a7b6-5432 10');
      await tester.pump();

      expect(c.text, '9876543210');
    });

    testWidgets('stops at ten digits', (WidgetTester tester) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.mobile, controller: c);
      await tester.enterText(find.byType(TextFormField), '98765432109999');
      await tester.pump();

      expect(c.text.length, 10);
    });
  });

  group('Blood group', () {
    testWidgets('is a dropdown of the eight recognised groups', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.bloodGroup, controller: c);

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      for (final String g in kBloodGroups) {
        expect(find.text(g).hitTestable(), findsWidgets, reason: g);
      }
    });

    testWidgets('an unrecognised stored group does not preselect', (
      WidgetTester tester,
    ) async {
      // Guards against a typo in imported data silently becoming a valid
      // selection on a medical field.
      final TextEditingController c = TextEditingController(text: 'XY+');
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.bloodGroup, controller: c);
      expect(find.text('XY+'), findsNothing);
    });
  });

  group('Photo', () {
    testWidgets('draws nothing inline - it has its own screen', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.photo, controller: c);

      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });
  });

  group('Address', () {
    testWidgets('is multiline and says how many lines print', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      addTearDown(c.dispose);

      await pump(tester, field: StudentField.address, controller: c);

      expect(find.text('Prints on up to 2 lines'), findsOneWidget);
    });
  });
}
