import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/firebase/sync_service.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeConnectivity extends Mock implements Connectivity {}

class _FakeStorage extends Mock implements FirebaseStorage {}

class _FakeRef extends Mock implements Reference {}

/// What happens to a submission when the photo cannot be uploaded.
///
/// This is not hypothetical: Cloud Storage was never provisioned on the live
/// Firebase project, so every photo upload fails against it. The old code let
/// that abort the whole row, which meant NOT ONE submission reached the office
/// - the review queue stayed empty and an operator's day of work looked lost,
/// when in fact only the picture was missing.
///
/// The student's details must land regardless, with the photo retried
/// separately.
void main() {
  setUpAll(() {
    // mocktail needs a stand-in for every type matched with any(). Neither is
    // ever interacted with - they are only passed around by the matcher.
    registerFallbackValue(File('fallback.png'));
    registerFallbackValue(SettableMetadata());
  });

  late AppDatabase db;
  late StudentRepository students;
  late SchoolRepository schools;
  late FakeFirebaseFirestore firestore;
  late _FakeConnectivity connectivity;
  late _FakeStorage storage;
  late Directory tempDir;
  late File photoFile;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    students = StudentRepository(db);
    schools = SchoolRepository(db);
    firestore = FakeFirebaseFirestore();
    connectivity = _FakeConnectivity();
    storage = _FakeStorage();

    // A real file on disk - the uploader checks existsSync() before trying,
    // and a missing file takes a different branch entirely.
    tempDir = Directory.systemTemp.createTempSync('id_entity_photo_test');
    photoFile = File('${tempDir.path}/photo.png')
      ..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47]);

    when(() => connectivity.checkConnectivity()).thenAnswer(
      (_) async => <ConnectivityResult>[ConnectivityResult.wifi],
    );
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => const Stream<List<ConnectivityResult>>.empty(),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SyncService build() => SyncService(
        students: students,
        schools: schools,
        firestore: firestore,
        storage: storage,
        connectivity: connectivity,
        isFirebaseReady: () => true,
      );

  /// Makes every Storage call throw [code], the way an unprovisioned bucket
  /// does.
  void storageFailsWith(String code) {
    final _FakeRef ref = _FakeRef();
    when(() => storage.ref()).thenReturn(ref);
    when(() => ref.child(any())).thenReturn(ref);
    when(() => ref.putFile(any(), any())).thenThrow(
      FirebaseException(plugin: 'firebase_storage', code: code),
    );
  }

  StudentEntry entry({String id = 'e1', bool withPhoto = true}) {
    final DateTime now = DateTime(2026, 9, 10);
    return StudentEntry(
      id: id,
      schoolId: 'school-a',
      name: 'RAMESH KUMAR',
      studentClass: '10',
      division: 'A',
      rollNumber: '12/A',
      localPhotoPath: withPhoto ? photoFile.path : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Map<String, Object?>?> remote(String id) async {
    final DocumentSnapshot<Map<String, Object?>> snap = await firestore
        .collection('schools')
        .doc('school-a')
        .collection('entries')
        .doc(id)
        .get();
    return snap.data();
  }

  group('Storage is not provisioned', () {
    test('the student details still reach the office', () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final Map<String, Object?>? doc = await remote('e1');
      expect(
        doc,
        isNotNull,
        reason: 'the whole point: a missing photo must not hide the student '
            'from the review queue',
      );
      expect(doc!['name'], 'RAMESH KUMAR');
      expect(doc['rollNumber'], '12/A');
      expect(doc['photoUrl'], isNull);
    });

    test('the row stays queued so the photo is retried', () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(
        after.syncStatus,
        SyncStatus.failed,
        reason: 'not synced - the photo is still outstanding',
      );
      expect(after.syncAttempts, 1);
      expect(after.remotePhotoUrl, isNull);
    });

    test('the operator is told the details DID upload', () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final String error = (await students.findById('e1'))!.syncError!;
      expect(error, contains('Details uploaded'));
      expect(
        error,
        contains('Do not retake'),
        reason: 'retaking a perfectly good photo would waste the operator time '
            'and would not fix a missing bucket',
      );
    });

    test('a bucket-not-found reads the same way', () async {
      storageFailsWith('bucket-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      expect(
        (await students.findById('e1'))!.syncError,
        contains('photo storage is not set up'),
      );
    });

    test('a permission failure blames access, not the photo', () async {
      storageFailsWith('unauthorized');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final String error = (await students.findById('e1'))!.syncError!;
      expect(error, contains('Details uploaded'));
      expect(error, contains('access'));
    });

    test('every entry in a batch still reaches the office', () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      for (int i = 0; i < 4; i++) {
        await students.save(entry(id: 'e$i'));
      }
      await sync.syncNow(schoolId: 'school-a');

      final QuerySnapshot<Map<String, Object?>> all = await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .get();
      expect(
        all.docs.length,
        4,
        reason: 'previously this was 0 and the admin saw an empty queue',
      );
    });

    test('a retry re-attempts the photo and does not duplicate the doc',
        () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      // Clear the backoff the way the Retry button does.
      await students.resetFailures('school-a');
      await sync.syncNow(schoolId: 'school-a');

      final QuerySnapshot<Map<String, Object?>> all = await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .get();
      expect(all.docs.length, 1);
      expect((await students.findById('e1'))!.syncStatus, SyncStatus.failed);
    });
  });

  group('Nothing else regressed', () {
    test('an entry with no photo at all syncs cleanly', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry(withPhoto: false));
      await sync.syncNow(schoolId: 'school-a');

      expect(await remote('e1'), isNotNull);
      expect(
        (await students.findById('e1'))!.syncStatus,
        SyncStatus.synced,
        reason: 'no photo was requested, so nothing is outstanding',
      );
    });

    test('a photo already uploaded is not re-uploaded', () async {
      // Storage is left unstubbed: touching it would throw, so this also
      // proves the upload is skipped rather than merely succeeding quietly.
      final SyncService sync = build();
      addTearDown(sync.dispose);

      final StudentEntry withUrl = entry().copyWith(
        remotePhotoUrl: 'https://example/already.png',
      );
      await students.save(withUrl);
      await sync.syncNow(schoolId: 'school-a');

      expect((await remote('e1'))!['photoUrl'], 'https://example/already.png');
      expect((await students.findById('e1'))!.syncStatus, SyncStatus.synced);
    });

    test('a photo file deleted from disk still parks immediately', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(
        entry().copyWith(localPhotoPath: '${tempDir.path}/gone.png'),
      );
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.syncStatus, SyncStatus.failed);
      expect(after.syncError, contains('Re-capture'));
      expect(
        after.syncAttempts,
        greaterThanOrEqualTo(8),
        reason: 'retrying cannot bring back a deleted file',
      );
      expect(
        await remote('e1'),
        isNull,
        reason: 'a card with no photo the operator believes exists should not '
            'silently enter the queue - this branch is unchanged',
      );
    });
  });
}
