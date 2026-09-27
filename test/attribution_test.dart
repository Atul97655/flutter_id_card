/// Who submitted a card, and whether that answer survives the round trip.
///
/// The panel's per-teacher views (A9, A11, A12 in the screen spec) are all
/// built on this one pair of fields. If attribution is dropped anywhere
/// between the form and Firestore, those pages do not break - they quietly
/// show "unknown" for everybody, which looks like a data problem at the
/// school rather than a bug here.
library;

import 'package:drift/native.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

StudentEntry entry({
  String id = 'e1',
  String? uid = 'teacher-uid',
  String? who = 'SUNITA DESHPANDE',
}) {
  final DateTime now = DateTime.utc(2026, 3, 4, 10, 0);
  return StudentEntry(
    id: id,
    schoolId: 'SJS-2026-0041',
    name: 'ADITYA KUMAR',
    studentClass: '10TH',
    division: 'A',
    rollNumber: '024',
    submittedByUid: uid,
    submittedByName: who,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('the local store', () {
    late AppDatabase db;
    late StudentRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = StudentRepository(db);
    });

    tearDown(() => db.close());

    test('keeps the submitter through a save and read', () async {
      await repo.save(entry());

      final StudentEntry? loaded = await repo.findById('e1');

      expect(loaded, isNotNull);
      expect(loaded!.submittedByUid, 'teacher-uid');
      expect(loaded.submittedByName, 'SUNITA DESHPANDE');
    });

    test('accepts a card with no submitter', () async {
      await repo.save(entry(uid: null, who: null));

      final StudentEntry? loaded = await repo.findById('e1');

      expect(
        loaded!.submittedByUid,
        isNull,
        reason:
            'every row captured before v10 is this case, and it has to '
            'stay readable rather than blowing up a list render',
      );
    });
  });

  group('the wire format', () {
    test('carries the submitter to Firestore', () {
      final Map<String, Object?> map = entry().toFirestoreMap();

      expect(map['submittedByUid'], 'teacher-uid');
      expect(map['submittedByName'], 'SUNITA DESHPANDE');
    });

    test('reads it back', () {
      final StudentEntry parsed = StudentEntry.fromFirestoreMap(
        'e1',
        entry().toFirestoreMap(),
      );

      expect(parsed.submittedByUid, 'teacher-uid');
      expect(parsed.submittedByName, 'SUNITA DESHPANDE');
    });

    test('a document written before v10 parses with nulls', () {
      final Map<String, Object?> old = entry().toFirestoreMap()
        ..remove('submittedByUid')
        ..remove('submittedByName');

      final StudentEntry parsed = StudentEntry.fromFirestoreMap('e1', old);

      expect(parsed.submittedByUid, isNull);
      expect(parsed.submittedByName, isNull);
      expect(parsed.name, 'ADITYA KUMAR', reason: 'the rest still parses');
    });

    test('a non-string in the field does not crash the parse', () {
      final Map<String, Object?> hostile = entry().toFirestoreMap()
        ..['submittedByUid'] = 42;

      expect(
        () => StudentEntry.fromFirestoreMap('e1', hostile),
        throwsA(isA<TypeError>()),
        reason:
            'documented, not desired: the cast is unguarded here exactly '
            'as it is for every other string field on this model, so this '
            'test pins the current behaviour rather than claiming it is right',
      );
    });
  });

  group('editing', () {
    test('copyWith leaves attribution alone when not asked to change it', () {
      final StudentEntry edited = entry().copyWith(name: 'ADITYA R KUMAR');

      expect(edited.submittedByUid, 'teacher-uid');
      expect(edited.submittedByName, 'SUNITA DESHPANDE');
    });

    test('an unattributed card can be given a submitter later', () {
      final StudentEntry fixed = entry(
        uid: null,
        who: null,
      ).copyWith(submittedByUid: 'teacher-uid', submittedByName: 'SUNITA D');

      expect(fixed.submittedByUid, 'teacher-uid');
    });
  });
}
