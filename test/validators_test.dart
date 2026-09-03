import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.mobile', () {
    test('accepts exactly 10 digits', () {
      expect(Validators.mobile('9876543210'), isNull);
    });

    test('rejects 9 digits', () {
      expect(Validators.mobile('987654321'), contains('10 digits'));
    });

    test('rejects 11 digits', () {
      expect(Validators.mobile('98765432101'), contains('10 digits'));
    });

    test('rejects letters and punctuation', () {
      expect(Validators.mobile('98765-4321'), contains('digits only'));
    });

    test('rejects empty when required', () {
      expect(Validators.mobile(''), contains('required'));
    });

    test('allows empty when the field is switched off for the school', () {
      expect(Validators.mobile('', isRequired: false), isNull);
    });
  });

  group('Validators.dateOfBirth', () {
    final DateTime today = DateTime(2026, 8, 25);

    test('accepts a plausible past date', () {
      expect(
        Validators.dateOfBirth(DateTime(2015, 3, 14), now: today),
        isNull,
      );
    });

    test('rejects today', () {
      expect(
        Validators.dateOfBirth(today, now: today),
        contains('in the past'),
      );
    });

    test('rejects a future date', () {
      expect(
        Validators.dateOfBirth(DateTime(2030), now: today),
        contains('in the past'),
      );
    });

    test('rejects a year that is obviously a typo', () {
      // 1015 instead of 2015 - the classic data-entry slip.
      expect(
        Validators.dateOfBirth(DateTime(1015, 3, 14), now: today),
        contains('check the year'),
      );
    });

    test('rejects null when required', () {
      expect(Validators.dateOfBirth(null, now: today), contains('required'));
    });

    test('accepts null when the field is switched off', () {
      expect(
        Validators.dateOfBirth(null, isRequired: false, now: today),
        isNull,
      );
    });

    test('accepts yesterday', () {
      expect(
        Validators.dateOfBirth(DateTime(2026, 8, 24), now: today),
        isNull,
      );
    });
  });

  group('Validators.bloodGroup', () {
    test('accepts every recognised group', () {
      for (final String group in kBloodGroups) {
        expect(Validators.bloodGroup(group), isNull, reason: group);
      }
    });

    test('rejects an unrecognised value', () {
      expect(Validators.bloodGroup('C+'), contains('valid blood group'));
    });
  });

  group('Validators.address', () {
    test('accepts a normal address', () {
      expect(Validators.address('12/A, MG ROAD, HUBLI - 580020'), isNull);
    });

    test('rejects an address too long to print on two lines', () {
      expect(
        Validators.address('A' * (Validators.addressMaxLength + 1)),
        contains('2 lines'),
      );
    });
  });

  group('Validators.name', () {
    test('rejects a single character', () {
      expect(Validators.name('R'), contains('too short'));
    });

    test('rejects whitespace only', () {
      expect(Validators.name('   '), contains('required'));
    });

    test('accepts a real name', () {
      expect(Validators.name('RAMESH KUMAR'), isNull);
    });
  });

  group('Validators.shortCode', () {
    test('accepts a single letter - divisions are commonly one character', () {
      // The div-badge card template is built entirely around single-letter
      // divisions (A-F); rejecting them would make that template unusable.
      expect(Validators.shortCode('A', label: 'Div'), isNull);
      expect(Validators.shortCode('B'), isNull);
    });

    test('accepts a single digit - classes like "1" are normal too', () {
      expect(Validators.shortCode('1', label: 'Class'), isNull);
    });

    test('still rejects empty', () {
      expect(Validators.shortCode('', label: 'Div'), contains('required'));
    });

    test('still rejects something absurdly long', () {
      expect(
        Validators.shortCode('A' * (Validators.nameMaxLength + 1), label: 'Div'),
        contains('40 characters'),
      );
    });
  });

  group('Validators.forField dispatch', () {
    test('routes each field kind to the right rule', () {
      expect(
        Validators.forField(StudentField.mobile, 'abc'),
        contains('digits only'),
      );
      expect(
        Validators.forField(StudentField.bloodGroup, 'O+'),
        isNull,
      );
      expect(
        Validators.forField(StudentField.name, 'RAMESH'),
        isNull,
      );
      expect(
        Validators.forField(
          StudentField.dob,
          '',
          parsedDate: DateTime(2015, 6, 1),
          now: DateTime(2026, 8, 25),
        ),
        isNull,
      );
    });

    test('accepts a single-letter Div - the regression that broke the demo',
        () {
      expect(Validators.forField(StudentField.division, 'B'), isNull);
    });

    test('accepts a single-digit Class', () {
      expect(Validators.forField(StudentField.studentClass, '1'), isNull);
    });

    test('the actual name fields keep the 2-character minimum', () {
      expect(
        Validators.forField(StudentField.name, 'R'),
        contains('too short'),
      );
      expect(
        Validators.forField(StudentField.fatherName, 'R'),
        contains('too short'),
      );
    });

    test('short-circuits to valid for a blank optional field', () {
      expect(
        Validators.forField(StudentField.mobile, '', isRequired: false),
        isNull,
      );
    });

    test('photo has no text rule of its own', () {
      expect(Validators.forField(StudentField.photo, ''), isNull);
    });
  });
}
