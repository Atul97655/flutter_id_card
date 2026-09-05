import 'package:flutter_id_card/features/data_entry/data/draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

EntryDraft draft({
  String schoolId = 's1',
  String name = 'RAMESH KUMAR',
  String? photoPath,
  DateTime? savedAt,
}) {
  return EntryDraft(
    schoolId: schoolId,
    name: name,
    studentClass: '10',
    division: 'A',
    mobile: '9876543210',
    photoPath: photoPath,
    savedAt: savedAt ?? DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const DraftStore store = DraftStore();

  setUp(() {
    // Each test starts from an empty preference store.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('hasContent', () {
    test('an untouched form is not worth restoring', () {
      const EntryDraft empty = EntryDraft(schoolId: 's1');
      expect(empty.hasContent, isFalse);
    });

    test('whitespace alone does not count as content', () {
      const EntryDraft blank = EntryDraft(schoolId: 's1', name: '   ');
      expect(blank.hasContent, isFalse);
    });

    test('any real field makes it worth restoring', () {
      expect(const EntryDraft(schoolId: 's1', name: 'R').hasContent, isTrue);
      expect(const EntryDraft(schoolId: 's1', mobile: '9').hasContent, isTrue);
      expect(
        const EntryDraft(schoolId: 's1', dobIso: '2012-04-17').hasContent,
        isTrue,
      );
    });

    test('a photo alone is worth restoring - it is the costliest to redo', () {
      expect(
        const EntryDraft(schoolId: 's1', photoPath: '/p.png').hasContent,
        isTrue,
      );
    });
  });

  group('save and load', () {
    test('round-trips every field', () async {
      const EntryDraft original = EntryDraft(
        schoolId: 's1',
        entryId: 'e9',
        name: 'RAMESH KUMAR',
        fatherName: 'SURESH KUMAR',
        studentClass: '10',
        division: 'A',
        bloodGroup: 'O+',
        dobIso: '2012-04-17T00:00:00.000',
        mobile: '9876543210',
        address: '12/A, MG ROAD',
        photoPath: '/tmp/p.png',
      );

      await store.save(original);
      final EntryDraft? loaded = await store.load('s1');

      expect(loaded, isNotNull);
      expect(loaded!.entryId, 'e9');
      expect(loaded.name, 'RAMESH KUMAR');
      expect(loaded.fatherName, 'SURESH KUMAR');
      expect(loaded.studentClass, '10');
      expect(loaded.division, 'A');
      expect(loaded.bloodGroup, 'O+');
      expect(loaded.dobIso, '2012-04-17T00:00:00.000');
      expect(loaded.mobile, '9876543210');
      expect(loaded.address, '12/A, MG ROAD');
      expect(loaded.photoPath, '/tmp/p.png');
    });

    test('returns nothing when none was saved', () async {
      expect(await store.load('s1'), isNull);
    });

    test('is not offered to a different school', () async {
      // Signing in as another school must never surface the previous
      // operator's half-typed student.
      await store.save(draft(schoolId: 's1'));
      expect(await store.load('s2'), isNull);
      expect(await store.load('s1'), isNotNull);
    });

    test('an empty draft is never offered', () async {
      await store.save(const EntryDraft(schoolId: 's1'));
      expect(await store.load('s1'), isNull);
    });

    test('only one draft is kept - the latest wins', () async {
      await store.save(draft(name: 'FIRST'));
      await store.save(draft(name: 'SECOND'));

      final EntryDraft? loaded = await store.load('s1');
      expect(loaded!.name, 'SECOND');
    });
  });

  group('expiry', () {
    test('a stale draft is discarded rather than offered', () async {
      // Restoring yesterday's half-typed student into today's session would
      // be confusing and probably wrong.
      await store.save(
        draft(savedAt: DateTime.now().subtract(const Duration(hours: 13))),
      );

      expect(await store.load('s1'), isNull);
    });

    test('a recent draft survives', () async {
      await store.save(
        draft(savedAt: DateTime.now().subtract(const Duration(hours: 2))),
      );

      expect(await store.load('s1'), isNotNull);
    });

    test('loading a stale draft also clears it from disk', () async {
      await store.save(
        draft(savedAt: DateTime.now().subtract(const Duration(days: 3))),
      );

      await store.load('s1');

      // Re-saving nothing and reloading proves the stale value is really gone
      // rather than just filtered on read.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('entry_draft'), isNull);
    });
  });

  group('clear', () {
    test('removes a saved draft', () async {
      await store.save(draft());
      expect(await store.load('s1'), isNotNull);

      await store.clear();
      expect(await store.load('s1'), isNull);
    });

    test('clearing when nothing is stored is harmless', () async {
      await store.clear();
      expect(await store.load('s1'), isNull);
    });
  });

  group('corrupt data', () {
    test('unparseable JSON is dropped, not thrown', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'entry_draft': 'not valid json {{{',
      });

      expect(await store.load('s1'), isNull);
    });

    test('valid JSON of the wrong shape is dropped', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'entry_draft': '["unexpected", "array"]',
      });

      expect(await store.load('s1'), isNull);
    });
  });
}
