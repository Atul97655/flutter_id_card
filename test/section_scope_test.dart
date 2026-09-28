/// Pulling only your own section.
///
/// The rules are what actually withhold another section's students, and they
/// are tested against the emulator. What is tested here is the half that
/// lives in the app, and it is not a nicety: Firestore does not filter a
/// result set down to what a rule allows, it refuses the entire query if any
/// document it would return fails. So a scoped teacher whose sync query
/// carries no scope does not get a short list - they get `permission-denied`
/// on every pass, forever, and the app looks broken rather than empty.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/services/firebase/sync_service.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeConnectivity extends Mock implements Connectivity {}

void main() {
  late AppDatabase db;
  late StudentRepository students;
  late SchoolRepository schools;
  late FakeFirebaseFirestore firestore;
  late SyncService sync;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    schools = SchoolRepository(db);
    firestore = FakeFirebaseFirestore();

    final _FakeConnectivity connectivity = _FakeConnectivity();
    // Tearoff rather than `() => connectivity.checkConnectivity()`: mocktail
    // invokes whatever it is handed, so the two are identical, and the
    // closure form trips `unnecessary_lambdas` on a local variable.
    when(connectivity.checkConnectivity)
        .thenAnswer((_) async => <ConnectivityResult>[ConnectivityResult.wifi]);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

    sync = SyncService(
      students: students,
      schools: schools,
      firestore: firestore,
      connectivity: connectivity,
      isFirebaseReady: () => true,
    );

    Future<void> remote(String id, String classLevel, String division) =>
        firestore
            .collection('schools')
            .doc('school-a')
            .collection('entries')
            .doc(id)
            .set(<String, Object?>{
              'schoolId': 'school-a',
              'name': 'STUDENT ${id.toUpperCase()}',
              'studentClass': classLevel,
              'division': division,
              'approvalStatus': 'approved',
              'createdAt': DateTime(2026, 9, 1).toUtc().toIso8601String(),
              'updatedAt': DateTime(2026, 9, 2).toUtc().toIso8601String(),
            });

    await remote('in-10a', '10', 'A');
    await remote('also-10a', '10', 'A');
    await remote('in-10b', '10', 'B');
    await remote('in-9a', '9', 'A');
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
  });

  Future<Set<String>> localIds() async =>
      (await students.listBySchool('school-a'))
          .map((StudentEntry e) => e.id)
          .toSet();

  test('a scoped teacher pulls only their own section', () async {
    await sync.syncNow(schoolId: 'school-a', classLevel: '10', division: 'A');

    expect(await localIds(), <String>{'in-10a', 'also-10a'});
  });

  test('the next section along never reaches the device', () async {
    await sync.syncNow(schoolId: 'school-a', classLevel: '10', division: 'A');

    final Set<String> ids = await localIds();
    expect(ids, isNot(contains('in-10b')));
    expect(
      ids,
      isNot(contains('in-9a')),
      reason: 'same section letter, different class - the scope is both',
    );
  });

  // Grandfathering. Every account that existed before sections is this one,
  // and an upgrade that silently emptied their app would read as data loss.
  test('an unscoped teacher still pulls the whole school', () async {
    await sync.syncNow(schoolId: 'school-a');

    expect(await localIds(), <String>{'in-10a', 'also-10a', 'in-10b', 'in-9a'});
  });

  test('half a scope is treated as no scope', () async {
    await sync.syncNow(schoolId: 'school-a', classLevel: '10');

    expect(
      (await localIds()).length,
      4,
      reason:
          'a query carrying only a class would be refused by the rules '
          'for every document in a school with more than one section, so the '
          'app must not send one',
    );
  });

  test('a scope matching nothing pulls nothing, and does not throw', () async {
    await sync.syncNow(schoolId: 'school-a', classLevel: '12', division: 'D');

    expect(await localIds(), isEmpty);
  });

  test(
    'the scope reaches the pull through start(), not just syncNow',
    () async {
      await sync.start(schoolId: 'school-a', classLevel: '10', division: 'A');

      expect(
        await localIds(),
        <String>{'in-10a', 'also-10a'},
        reason:
            'the periodic and connectivity-triggered passes go through '
            'start(), so a scope that only reached syncNow would be dropped on '
            'every pass after the first',
      );
    },
  );
}
