import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchoolConfig field toggles', () {
    test('renders only the enabled fields, in canonical order', () {
      const SchoolConfig config = SchoolConfig(
        id: 's1',
        name: 'TEST SCHOOL',
        enabledFieldKeys: <String>{'mobile', 'fatherName'},
      );

      expect(
        config.enabledFields.map((StudentField f) => f.key).toList(),
        // name and photo are always-on; the rest follow enum order.
        <String>['name', 'fatherName', 'mobile', 'photo'],
      );
    });

    test('always-on fields cannot be switched off', () {
      const SchoolConfig config = SchoolConfig(id: 's1', name: 'X');
      final SchoolConfig updated =
          config.withFieldEnabled(StudentField.name, false);

      expect(updated.isEnabled(StudentField.name), isTrue);
      expect(updated.isEnabled(StudentField.photo), isTrue);
    });

    test('toggling a field on and off round-trips', () {
      const SchoolConfig config = SchoolConfig(id: 's1', name: 'X');
      expect(config.isEnabled(StudentField.bloodGroup), isFalse);

      final SchoolConfig on = config.withFieldEnabled(StudentField.bloodGroup, true);
      expect(on.isEnabled(StudentField.bloodGroup), isTrue);

      final SchoolConfig off = on.withFieldEnabled(StudentField.bloodGroup, false);
      expect(off.isEnabled(StudentField.bloodGroup), isFalse);
    });

    test('an unknown key from a newer build is ignored, not fatal', () {
      const SchoolConfig config = SchoolConfig(
        id: 's1',
        name: 'X',
        enabledFieldKeys: <String>{'mobile', 'someFutureField'},
      );
      expect(
        config.enabledFields.map((StudentField f) => f.key),
        isNot(contains('someFutureField')),
      );
      expect(config.isEnabled(StudentField.mobile), isTrue);
    });
  });

  group('SchoolConfig.parseHex', () {
    test('accepts the documented forms', () {
      expect(SchoolConfig.parseHex('#D32F2F', 0), 0xFFD32F2F);
      expect(SchoolConfig.parseHex('D32F2F', 0), 0xFFD32F2F);
      expect(SchoolConfig.parseHex('#FFD32F2F', 0), 0xFFD32F2F);
      expect(SchoolConfig.parseHex('80D32F2F', 0), 0x80D32F2F);
    });

    test('falls back rather than throwing on a typo', () {
      // A bad colour override must never stop a school from printing.
      expect(SchoolConfig.parseHex('not-a-colour', 0xFF112233), 0xFF112233);
      expect(SchoolConfig.parseHex('#FFF', 0xFF112233), 0xFF112233);
      expect(SchoolConfig.parseHex(null, 0xFF112233), 0xFF112233);
    });
  });

  group('field key encoding', () {
    test('empty string decodes to no fields, not one blank field', () {
      expect(SchoolRepository.decodeFieldKeys(''), isEmpty);
    });

    test('round-trips through the comma-joined storage form', () {
      final Set<String> keys = <String>{'name', 'mobile', 'dob'};
      final String encoded = SchoolRepository.encodeFieldKeys(keys);
      expect(SchoolRepository.decodeFieldKeys(encoded), keys);
    });

    test('tolerates stray whitespace', () {
      expect(
        SchoolRepository.decodeFieldKeys('name, mobile ,dob'),
        <String>{'name', 'mobile', 'dob'},
      );
    });
  });

  group('StudentEntry.exportBaseName', () {
    StudentEntry entry({String name = 'RAMESH KUMAR', String cls = '10'}) {
      return StudentEntry(
        id: 'x',
        schoolId: 's',
        name: name,
        studentClass: cls,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
    }

    test('builds STUDENTNAME_CLASS', () {
      expect(entry().exportBaseName, 'RAMESH_KUMAR_10');
    });

    test('strips characters Windows rejects in a filename', () {
      expect(
        entry(name: 'A/B\\C:D*E?F"G<H>I|J').exportBaseName,
        'ABCDEFGHIJ_10',
      );
    });

    test('handles a missing class', () {
      expect(entry(cls: '').exportBaseName, 'RAMESH_KUMAR');
    });

    test('handles a missing name', () {
      expect(entry(name: '').exportBaseName, 'UNNAMED_10');
    });
  });

  group('StudentEntry', () {
    final StudentEntry base = StudentEntry(
      id: 'x',
      schoolId: 's',
      name: 'RAMESH',
      dob: DateTime(2015, 3, 4),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('formats DOB as DD-MM-YYYY', () {
      expect(base.formattedDob, '04-03-2015');
    });

    test('valueOf reads every field generically', () {
      expect(base.valueOf(StudentField.name), 'RAMESH');
      expect(base.valueOf(StudentField.dob), '04-03-2015');
      expect(base.valueOf(StudentField.mobile), '');
    });

    test('copyWith can explicitly clear a nullable field', () {
      // Without the explicit flag, passing null to copyWith is indistinguishable
      // from "leave it alone".
      expect(base.copyWith(clearDob: true).dob, isNull);
      expect(base.copyWith().dob, base.dob);
    });

    test('survives a Firestore round-trip without shifting the birth date', () {
      final Map<String, Object?> map = base.toFirestoreMap();
      final StudentEntry restored = StudentEntry.fromFirestoreMap('x', map);
      expect(restored.formattedDob, base.formattedDob);
      expect(restored.name, base.name);
    });
  });

  group('SchoolConfig classes, divisions and signature', () {
    test('defaults are populated when empty', () {
      const SchoolConfig config = SchoolConfig(id: 's1', name: 'DEMO');
      expect(config.classes, contains('10'));
      expect(config.divisions, contains('A'));
    });

    test('custom classes and divisions survive round-trip', () {
      const SchoolConfig custom = SchoolConfig(
        id: 's2',
        name: 'CUSTOM SCHOOL',
        classes: <String>['Grade 1', 'Grade 2', 'Grade 3'],
        divisions: <String>['Red', 'Blue', 'Green'],
        principalSignatureUrl: 'https://example.com/sig.png',
      );

      final Map<String, Object?> map = custom.toFirestoreMap();
      final SchoolConfig restored = SchoolConfig.fromFirestoreMap('s2', map);

      expect(restored.classes, <String>['Grade 1', 'Grade 2', 'Grade 3']);
      expect(restored.divisions, <String>['Red', 'Blue', 'Green']);
      expect(restored.principalSignatureUrl, 'https://example.com/sig.png');
    });
  });
}
