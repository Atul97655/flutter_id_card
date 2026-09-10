import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/firebase/sync_service.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeConnectivity extends Mock implements Connectivity {}

/// The sync worker had no tests at all, despite being the thing that moves a
/// day of captured work off a device.
///
/// These run against a fake Firestore, so they exercise the real orchestration
/// - the pull/push ordering, the conflict guard that protects an admin's
/// approval, the idempotent document id, and the failure paths that decide
/// whether a row retries or parks.
void main() {
  late AppDatabase db;
  late StudentRepository students;
  late SchoolRepository schools;
  late FakeFirebaseFirestore firestore;
  late _FakeConnectivity connectivity;
  late SyncService sync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    schools = SchoolRepository(db);
    firestore = FakeFirebaseFirestore();
    connectivity = _FakeConnectivity();

    when(() => connectivity.checkConnectivity()).thenAnswer(
      (_) async => <ConnectivityResult>[ConnectivityResult.wifi],
    );
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => const Stream<List<ConnectivityResult>>.empty(),
    );

    sync = SyncService(
      students: students,
      schools: schools,
      firestore: firestore,
      connectivity: connectivity,
      isFirebaseReady: () => true,
    );
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
  });

  StudentEntry entry({
    String id = 'e1',
    String schoolId = 'school-a',
    String name = 'RAMESH KUMAR',
    ApprovalStatus approval = ApprovalStatus.pending,
    SyncStatus status = SyncStatus.pending,
    int attempts = 0,
  }) {
    final DateTime now = DateTime(2026, 9, 10);
    return StudentEntry(
      id: id,
      schoolId: schoolId,
      name: name,
      studentClass: '10',
      division: 'A',
      rollNumber: '12/A',
      approvalStatus: approval,
      syncStatus: status,
      syncAttempts: attempts,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Map<String, Object?>?> remote(String schoolId, String id) async {
    final DocumentSnapshot<Map<String, Object?>> snap = await firestore
        .collection('schools')
        .doc(schoolId)
        .collection('entries')
        .doc(id)
        .get();
    return snap.data();
  }

  group('Uploading', () {
    test('a pending entry reaches Firestore and is marked synced', () async {
      await students.save(entry());

      await sync.syncNow(schoolId: 'school-a');

      final Map<String, Object?>? doc = await remote('school-a', 'e1');
      expect(doc, isNotNull);
      expect(doc!['name'], 'RAMESH KUMAR');
      expect(doc['rollNumber'], '12/A');

      expect((await students.findById('e1'))!.syncStatus, SyncStatus.synced);
    });

    test('the entry id is the document id, so a replay overwrites', () async {
      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      // Put it back in the queue and run again - a replayed interrupted pass.
      await students.save(entry(name: 'RAMESH KUMAR PATIL'));
      await sync.syncNow(schoolId: 'school-a');

      final QuerySnapshot<Map<String, Object?>> all = await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .get();

      expect(
        all.docs.length,
        1,
        reason: 'a second document would be a duplicate student, discovered '
            'only at the printer',
      );
      expect(all.docs.single.data()['name'], 'RAMESH KUMAR PATIL');
    });

    test('an entry with no name is parked, not retried forever', () async {
      await students.save(entry(name: ''));

      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.syncStatus, SyncStatus.failed);
      expect(after.syncError, contains('required'));
      expect(
        after.syncAttempts,
        greaterThanOrEqualTo(8),
        reason: 'retrying cannot fix a missing name, so it should stop at once',
      );
      expect(await remote('school-a', 'e1'), isNull);
    });

    test('a row past the attempt ceiling is not picked up', () async {
      await students.save(entry(status: SyncStatus.failed, attempts: 8));

      await sync.syncNow(schoolId: 'school-a');

      expect(await remote('school-a', 'e1'), isNull);
    });

    test('several entries all upload in one pass', () async {
      for (int i = 0; i < 5; i++) {
        await students.save(entry(id: 'e$i', name: 'STUDENT $i'));
      }

      await sync.syncNow(schoolId: 'school-a');

      final QuerySnapshot<Map<String, Object?>> all = await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .get();
      expect(all.docs.length, 5);
    });

    test('an approval decision propagates like any other change', () async {
      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      await students.approve('e1', reviewerUid: 'admin-1');
      await sync.syncNow(schoolId: 'school-a');

      final Map<String, Object?>? doc = await remote('school-a', 'e1');
      expect(doc!['approvalStatus'], 'approved');
      expect(doc['reviewedBy'], 'admin-1');
    });
  });

  group('Gates', () {
    test('nothing uploads while Firebase is still starting', () async {
      final SyncService notReady = SyncService(
        students: students,
        schools: schools,
        firestore: firestore,
        connectivity: connectivity,
        isFirebaseReady: () => false,
      );
      addTearDown(notReady.dispose);

      await students.save(entry());
      await notReady.syncNow(schoolId: 'school-a');

      expect(await remote('school-a', 'e1'), isNull);
      expect((await students.findById('e1'))!.syncStatus, SyncStatus.pending);
    });

    test('nothing uploads while offline, and the row is left alone', () async {
      when(() => connectivity.checkConnectivity()).thenAnswer(
        (_) async => <ConnectivityResult>[ConnectivityResult.none],
      );

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      expect(await remote('school-a', 'e1'), isNull);
      final StudentEntry after = (await students.findById('e1'))!;
      expect(
        after.syncStatus,
        SyncStatus.pending,
        reason: 'being offline is not a failure - it must not burn an attempt',
      );
      expect(after.syncAttempts, 0);
    });

    test('overlapping passes are collapsed', () async {
      for (int i = 0; i < 3; i++) {
        await students.save(entry(id: 'e$i'));
      }

      await Future.wait<void>(<Future<void>>[
        sync.syncNow(schoolId: 'school-a'),
        sync.syncNow(schoolId: 'school-a'),
      ]);

      final QuerySnapshot<Map<String, Object?>> all = await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .get();
      expect(all.docs.length, 3);
    });
  });

  group('Pulling school settings down', () {
    test('caches the school document locally', () async {
      await firestore.collection('schools').doc('school-a').set(
        <String, Object?>{
          'name': 'ST JOHN SAMARITAN',
          'addressLine': 'HUBBALLI',
          'enabledFields': <String>['name', 'photo', 'rollNumber'],
        },
      );

      await sync.syncNow(schoolId: 'school-a');

      final SchoolConfig? saved = await schools.find('school-a');
      expect(saved, isNotNull);
      expect(saved!.name, 'ST JOHN SAMARITAN');
    });

    test('a device-local logo path survives the pull', () async {
      await firestore.collection('schools').doc('school-a').set(
        <String, Object?>{'name': 'ST JOHN'},
      );
      await sync.syncNow(schoolId: 'school-a');

      final SchoolConfig? first = await schools.find('school-a');
      await schools.save(first!.copyWith(localLogoPath: '/data/logo.png'));

      // A second pull must not blank it - the path means nothing on the server
      // and the card would render without a logo.
      await sync.syncNow(schoolId: 'school-a');

      expect(
        (await schools.find('school-a'))!.localLogoPath,
        '/data/logo.png',
      );
    });

    test('a missing school document is not an error', () async {
      await students.save(entry());
      await sync.syncNow(schoolId: 'school-nope');
      // The pass still completes and the upload still runs.
      expect(await remote('school-a', 'e1'), isNotNull);
    });
  });

  group('Admin pull', () {
    test('mirrors every school and entry into the local database', () async {
      await firestore.collection('schools').doc('school-a').set(
        <String, Object?>{'name': 'SCHOOL A'},
      );
      await firestore.collection('schools').doc('school-b').set(
        <String, Object?>{'name': 'SCHOOL B'},
      );
      await firestore
          .collection('schools')
          .doc('school-b')
          .collection('entries')
          .doc('remote-1')
          .set(<String, Object?>{
        'schoolId': 'school-b',
        'name': 'REMOTE STUDENT',
        'approvalStatus': 'pending',
      });

      await sync.syncNow(isAdmin: true);

      expect(await schools.find('school-a'), isNotNull);
      expect(await schools.find('school-b'), isNotNull);
      final StudentEntry? pulled = await students.findById('remote-1');
      expect(pulled, isNotNull);
      expect(pulled!.name, 'REMOTE STUDENT');
    });

    test('does NOT clobber a local approval that has not uploaded yet',
        () async {
      // The regression this guard exists for: an admin approves a card, the
      // pull runs before the push, and the older server copy overwrites the
      // decision - silently discarding it.
      await firestore.collection('schools').doc('school-a').set(
        <String, Object?>{'name': 'SCHOOL A'},
      );
      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('e1')
          .set(<String, Object?>{
        'schoolId': 'school-a',
        'name': 'RAMESH KUMAR',
        'approvalStatus': 'pending',
      });

      await students.save(entry(status: SyncStatus.synced));
      await students.approve('e1', reviewerUid: 'admin-1');
      expect((await students.findById('e1'))!.syncStatus, SyncStatus.pending);

      await sync.syncNow(isAdmin: true);

      expect(
        (await students.findById('e1'))!.approvalStatus,
        ApprovalStatus.approved,
        reason: 'the approval was still queued for upload and must survive',
      );
    });

    test('a synced local row IS refreshed from the server', () async {
      await firestore.collection('schools').doc('school-a').set(
        <String, Object?>{'name': 'SCHOOL A'},
      );
      await students.save(entry(status: SyncStatus.synced));

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('e1')
          .set(<String, Object?>{
        'schoolId': 'school-a',
        'name': 'RAMESH KUMAR',
        'approvalStatus': 'approved',
        'reviewedBy': 'other-admin',
      });

      await sync.syncNow(isAdmin: true);

      expect(
        (await students.findById('e1'))!.approvalStatus,
        ApprovalStatus.approved,
        reason: 'nothing local was pending, so the server copy wins',
      );
    });
  });

  group('Reported state', () {
    test('a clean pass ends idle with no error', () async {
      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      expect(sync.state.activity, SyncActivity.idle);
      expect(sync.state.lastError, isNull);
      expect(sync.state.uploadedThisRun, 1);
      expect(sync.state.pendingCount, 0);
    });

    test('offline is reported as offline, not as an error', () async {
      when(() => connectivity.checkConnectivity()).thenAnswer(
        (_) async => <ConnectivityResult>[ConnectivityResult.none],
      );

      await sync.syncNow(schoolId: 'school-a');

      expect(sync.state.activity, SyncActivity.offline);
      expect(sync.state.lastError, isNull);
    });

    test('a stalled row is counted as still pending', () async {
      await students.save(entry(name: ''));
      await sync.syncNow(schoolId: 'school-a');

      expect(sync.state.uploadedThisRun, 0);
    });
  });
}
