import 'dart:io';

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

/// Telling "nothing uploaded" apart from "details uploaded, photo pending".
///
/// Reported from the field: straight after submitting a card the app showed a
/// red **Upload failed** on the progress timeline, while the text underneath
/// said the details HAD uploaded. The title contradicted its own body, and it
/// sent operators back to re-shoot photos that were never the problem.
///
/// The cause was that a photo-only failure marks the row `failed`, and the
/// timeline had no way to see that the document itself had landed.
void main() {
  setUpAll(() {
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

    tempDir = Directory.systemTemp.createTempSync('id_entity_pending_test');
    photoFile = File('${tempDir.path}/photo.png')
      ..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47]);

    when(() => connectivity.checkConnectivity()).thenAnswer(
      (_) async => <ConnectivityResult>[ConnectivityResult.wifi],
    );
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => const Stream<List<ConnectivityResult>>.empty(),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    await db.close();
  });

  SyncService build() => SyncService(
        students: students,
        schools: schools,
        firestore: firestore,
        storage: storage,
        connectivity: connectivity,
        isFirebaseReady: () => true,
      );

  void storageFailsWith(String code) {
    final _FakeRef ref = _FakeRef();
    when(() => storage.ref()).thenReturn(ref);
    when(() => ref.child(any())).thenReturn(ref);
    when(() => ref.putFile(any(), any())).thenThrow(
      FirebaseException(plugin: 'firebase_storage', code: code),
    );
  }

  StudentEntry entry({String id = 'e1', bool withPhoto = true}) {
    final DateTime now = DateTime(2026, 9, 16);
    return StudentEntry(
      id: id,
      schoolId: 'school-a',
      name: 'TEJASWINI DASH',
      studentClass: '10',
      division: 'A',
      localPhotoPath: withPhoto ? photoFile.path : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Schema v8', () {
    test('declares version 8', () {
      expect(db.schemaVersion, 8);
    });

    test('a brand-new entry has not reached the server', () async {
      await students.save(entry());
      final StudentEntry saved = (await students.findById('e1'))!;

      expect(saved.detailsSyncedAt, isNull);
      expect(saved.detailsReachedServer, isFalse);
      expect(saved.awaitingPhotoUpload, isFalse);
    });
  });

  group('A photo-only failure', () {
    test('still records that the details reached the office', () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;

      expect(
        after.detailsReachedServer,
        isTrue,
        reason: 'the Firestore document was written before the photo failed',
      );
      expect(
        after.awaitingPhotoUpload,
        isTrue,
        reason: 'this is the state the timeline must show as pending, not failed',
      );
      // The row is still `failed` so the photo keeps being retried - the point
      // is that the UI can now tell the two apart.
      expect(after.syncStatus, SyncStatus.failed);
    });

    test('is NOT a hard upload failure', () async {
      storageFailsWith('object-not-found');
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;

      // What the timeline keys off. Before the fix this was indistinguishable
      // from a genuine failure and rendered as a red "Upload failed".
      final bool hardFailure =
          after.syncStatus == SyncStatus.failed && !after.detailsReachedServer;

      expect(hardFailure, isFalse);
    });
  });

  group('A genuine failure is still a failure', () {
    test('an entry with no name never reaches the server', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(
        entry().copyWith(name: ''),
      );
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;

      expect(after.syncStatus, SyncStatus.failed);
      expect(
        after.detailsReachedServer,
        isFalse,
        reason: 'the pre-flight rejected it before any write',
      );
      expect(
        after.syncStatus == SyncStatus.failed && !after.detailsReachedServer,
        isTrue,
        reason: 'this one SHOULD render as a red Upload failed',
      );
    });

    test('a deleted photo file never reaches the server either', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(
        entry().copyWith(localPhotoPath: '${tempDir.path}/gone.png'),
      );
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.detailsReachedServer, isFalse);
      expect(after.syncError, contains('Re-capture'));
    });

    test('offline leaves it untouched, not failed', () async {
      when(() => connectivity.checkConnectivity()).thenAnswer(
        (_) async => <ConnectivityResult>[ConnectivityResult.none],
      );
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.syncStatus, SyncStatus.pending);
      expect(after.detailsReachedServer, isFalse);
      expect(after.awaitingPhotoUpload, isFalse);
    });
  });

  group('A clean upload', () {
    test('marks both the row synced and the details landed', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      // No photo requested, so nothing touches Storage.
      await students.save(entry(withPhoto: false));
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.syncStatus, SyncStatus.synced);
      expect(after.detailsReachedServer, isTrue);
      expect(
        after.awaitingPhotoUpload,
        isFalse,
        reason: 'there was never a photo to wait for',
      );
    });

    test('an already-uploaded photo is not pending', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(
        entry().copyWith(remotePhotoUrl: 'https://example/p.png'),
      );
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.syncStatus, SyncStatus.synced);
      expect(after.awaitingPhotoUpload, isFalse);
    });
  });
}
