import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_id_card/features/photo_capture/data/photo_storage.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/firebase/inline_photo.dart';
import 'package:flutter_id_card/shared/services/firebase/sync_service.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';

class _FakeConnectivity extends Mock implements Connectivity {}

class _FakeStorage extends Mock implements FirebaseStorage {}

class _FakeRef extends Mock implements Reference {}

/// Photos travelling inside Firestore.
///
/// ## Why this exists at all
///
/// Cloud Storage is not provisioned on this Firebase project and cannot be
/// without moving it to the Blaze plan. Until this landed, that single fact
/// meant **no photo ever left the capturing phone**: the details synced, the
/// picture did not, and the office saw every approved card as "no photo -
/// cannot print". The only machine that could print a card was the one that
/// took the picture, which is not a system.
///
/// So the photo now rides in Firestore when Storage refuses it. These tests
/// pin the three things that has to get right: the encoding fits in a
/// document, a Storage failure degrades to the inline route instead of
/// stranding the photo, and records already at the office get theirs sent
/// without re-pushing anything an operator is not allowed to change.
void main() {
  setUpAll(() {
    registerFallbackValue(File('fallback.png'));
    registerFallbackValue(SettableMetadata());
  });

  // A real 360x450 PNG, the exact shape the capture pipeline produces.
  late Uint8List cardPortrait;

  setUpAll(() {
    final img.Image src = img.Image(width: 360, height: 450);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        src.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    cardPortrait = Uint8List.fromList(img.encodePng(src));
  });

  group('Encoding a photo for transport', () {
    test(
      'produces a thumbnail and a full frame, both decodable JPEG',
      () async {
        final InlinePhoto? photo = await encodeInlinePhoto(cardPortrait);

        expect(photo, isNotNull);
        expect(photo!.width, 360);
        expect(photo.height, 450);

        final img.Image? full = img.decodeJpg(base64Decode(photo.fullBase64));
        expect(full, isNotNull, reason: 'the office has to be able to open it');
        expect(full!.width, 360);
        expect(full.height, 450);

        final img.Image? thumb = img.decodeJpg(base64Decode(photo.thumbBase64));
        expect(thumb, isNotNull);
        expect(thumb!.height, kThumbLongEdge);
      },
    );

    test('fits inside a Firestore document with room to spare', () async {
      final InlinePhoto photo = (await encodeInlinePhoto(cardPortrait))!;

      // A document is capped just under 1 MiB in total. Blowing that would not
      // merely fail the write - it would make the entry itself unwritable, so
      // the budget is the whole reason this encoding is JPEG and not the PNG
      // the pipeline already has on disk.
      expect(photo.fullBase64.length, lessThan(kMaxInlinePhotoChars));
      expect(
        photo.fullBase64.length,
        lessThan(200 * 1024),
        reason: 'a card portrait should encode to tens of KB, not hundreds',
      );
    });

    test('the thumbnail is small enough to ride on every row', () async {
      final InlinePhoto photo = (await encodeInlinePhoto(cardPortrait))!;

      // The admin panel lists every submission across every school in one
      // query. This is the number that decides whether that stays affordable.
      expect(
        photo.thumbBase64.length,
        lessThan(12 * 1024),
        reason: 'hundreds of these are downloaded to render one table',
      );
      expect(
        photo.thumbBase64.length,
        lessThan(photo.fullBase64.length),
        reason: 'a thumbnail larger than the frame would defeat the split',
      );
    });

    test('unreadable bytes are not an error, just no photo', () async {
      final InlinePhoto? photo = await encodeInlinePhoto(
        Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      );

      // A corrupt file must not block the student's details from reaching the
      // office - losing the picture is recoverable, losing the record is not.
      expect(photo, isNull);
    });
  });

  group('What this costs at a real school', () {
    // Carrying a thumbnail on every entry is what makes a list of submissions
    // show faces without a read per row. It also means the admin panel's one
    // collection-group query - which reads EVERY entry across EVERY school -
    // now carries that thumbnail for every student in the system.
    //
    // That trade is worth measuring rather than assuming, because the failure
    // mode is not an error: it is a dashboard that takes ten seconds to open
    // and a data bill, on someone else's phone, discovered in production.
    //
    // These numbers are a budget, not a benchmark. If a future change to the
    // encoder pushes them up, this fails and says so.

    test('one thumbnail stays inside its per-row budget', () async {
      final InlinePhoto photo = (await encodeInlinePhoto(cardPortrait))!;
      final int perRow = photo.thumbBase64.length;

      expect(
        perRow,
        lessThan(12 * 1024),
        reason: 'the per-row cost of showing a face in a list',
      );
    });

    test('a 500-student school loads in a few megabytes, not tens', () async {
      final InlinePhoto photo = (await encodeInlinePhoto(cardPortrait))!;

      // A single large school. The client has one school today; this is the
      // shape of the problem at the size they are selling into.
      const int students = 500;
      final double megabytes =
          (photo.thumbBase64.length * students) / (1024 * 1024);

      expect(
        megabytes,
        lessThan(6),
        reason:
            'the dashboard reads every entry at once - past a few MB this '
            'stops being a page load and starts being a download',
      );
    });

    test('the full frames are NOT part of that', () async {
      final InlinePhoto photo = (await encodeInlinePhoto(cardPortrait))!;

      const int students = 500;
      final double thumbsMb =
          (photo.thumbBase64.length * students) / (1024 * 1024);
      final double fullMb =
          (photo.fullBase64.length * students) / (1024 * 1024);

      // The reason the two are stored apart. Were the full frame on the entry
      // document, opening the dashboard would pull this instead.
      expect(
        fullMb,
        greaterThan(thumbsMb * 4),
        reason:
            'if these ever converge, the split has stopped paying for '
            'itself and the storage layout should be revisited',
      );
    });

    test(
      'a photo stays well inside the free Firestore tier per student',
      () async {
        final InlinePhoto photo = (await encodeInlinePhoto(cardPortrait))!;
        final int perStudent = photo.fullBytes + photo.thumbBase64.length;

        // 1 GiB free. At this size that is roughly 15,000 students, which is
        // far beyond anything this client is selling - so inline photos do not
        // quietly create a bill.
        expect(perStudent, lessThan(70 * 1024));
      },
    );
  });

  group('When Storage refuses the photo', () {
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

      tempDir = Directory.systemTemp.createTempSync('id_entity_inline_test');
      photoFile = File('${tempDir.path}/photo.png')
        ..writeAsBytesSync(cardPortrait);

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => <ConnectivityResult>[ConnectivityResult.wifi]);
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

      // The state this whole feature exists for: no bucket.
      final _FakeRef ref = _FakeRef();
      when(() => storage.ref()).thenReturn(ref);
      when(() => ref.child(any())).thenReturn(ref);
      when(() => ref.putFile(any(), any())).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'bucket-not-found'),
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

    StudentEntry entry({String id = 'e1'}) {
      final DateTime now = DateTime(2026, 9, 16);
      return StudentEntry(
        id: id,
        schoolId: 'school-a',
        name: 'TEJASWINI DASH',
        studentClass: '10',
        division: 'A',
        localPhotoPath: photoFile.path,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('the photo goes to Firestore instead, and the row settles', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(entry());
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;

      expect(
        after.syncStatus,
        SyncStatus.synced,
        reason:
            'the photo did reach the office, so the row is done - it must '
            'not sit in failed forever retrying a bucket that does not exist',
      );
      expect(after.syncError, isNull);
      expect(after.photoThumb, isNotNull);
      expect(after.photoReachedServer, isTrue);
      expect(after.awaitingPhotoUpload, isFalse);
    });

    test(
      'the full frame lands in its own document, not on the entry',
      () async {
        final SyncService sync = build();
        addTearDown(sync.dispose);

        await students.save(entry());
        await sync.syncNow(schoolId: 'school-a');

        final Map<String, Object?> media =
            (await firestore
                    .collection('schools')
                    .doc('school-a')
                    .collection('entries')
                    .doc('e1')
                    .collection('media')
                    .doc('photo')
                    .get())
                .data() ??
            <String, Object?>{};

        expect(media['contentType'], 'image/jpeg');
        expect(media['data'], isA<String>());
        expect(
          img.decodeJpg(base64Decode(media['data']! as String)),
          isNotNull,
        );

        final Map<String, Object?> doc =
            (await firestore
                    .collection('schools')
                    .doc('school-a')
                    .collection('entries')
                    .doc('e1')
                    .get())
                .data() ??
            <String, Object?>{};

        expect(doc['photoThumb'], isA<String>());
        expect(
          (doc['photoThumb']! as String).length,
          lessThan((media['data']! as String).length),
          reason:
              'the entry carries the thumbnail; the full frame stays out of '
              'the list query that reads every school at once',
        );
        expect(
          doc['photoUrl'],
          isNull,
          reason:
              'there is no Storage URL, and inventing one would break print',
        );
      },
    );

    test('a photo file the OS deleted is still a hard failure', () async {
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await students.save(
        entry().copyWith(localPhotoPath: '${tempDir.path}/gone.png'),
      );
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;

      // The inline route cannot rescue bytes that are not there. Retrying
      // would burn all eight attempts for nothing, so it goes to the operator.
      expect(after.syncStatus, SyncStatus.failed);
      expect(after.syncError, contains('Re-capture'));
      expect(after.photoThumb, isNull);
    });
  });

  group('Backfilling records the office already holds', () {
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

      tempDir = Directory.systemTemp.createTempSync('id_entity_backfill_test');
      photoFile = File('${tempDir.path}/photo.png')
        ..writeAsBytesSync(cardPortrait);

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => <ConnectivityResult>[ConnectivityResult.wifi]);
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

      final _FakeRef ref = _FakeRef();
      when(() => storage.ref()).thenReturn(ref);
      when(() => ref.child(any())).thenReturn(ref);
      when(() => ref.putFile(any(), any())).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'bucket-not-found'),
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

    /// A submission from before inline photos: settled, approved by the office,
    /// and permanently unprintable because its picture never left the phone.
    Future<void> seedStrandedEntry() async {
      final DateTime then = DateTime(2026, 9, 13);

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('old')
          .set(<String, Object?>{
            'schoolId': 'school-a',
            'name': 'ATUL',
            'approvalStatus': 'approved',
            'reviewedBy': 'admin-uid',
            'createdAt': then.toUtc().toIso8601String(),
            'updatedAt': then.toUtc().toIso8601String(),
          });

      await students.save(
        StudentEntry(
          id: 'old',
          schoolId: 'school-a',
          name: 'ATUL',
          approvalStatus: ApprovalStatus.approved,
          reviewedBy: 'admin-uid',
          localPhotoPath: photoFile.path,
          syncStatus: SyncStatus.synced,
          detailsSyncedAt: then,
          createdAt: then,
          updatedAt: then,
        ),
      );
    }

    test('a settled row with no server photo is picked up', () async {
      await seedStrandedEntry();

      // Not "due for upload" by any normal measure - it is synced, so the
      // ordinary queue will never look at it again. That is exactly why the
      // backfill is a separate pass.
      expect(await students.dueForUpload(), isEmpty);
      expect((await students.needingPhotoBackfill()).single.id, 'old');
    });

    test('and its photo is sent without re-pushing the record', () async {
      await seedStrandedEntry();
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await sync.syncNow(schoolId: 'school-a');

      final Map<String, Object?> doc =
          (await firestore
                  .collection('schools')
                  .doc('school-a')
                  .collection('entries')
                  .doc('old')
                  .get())
              .data() ??
          <String, Object?>{};

      expect(doc['photoThumb'], isA<String>());

      // The critical part. An operator may not change a review decision, so a
      // backfill that re-sent the whole document would be refused by the rules
      // the moment the admin had approved anything - which is precisely the
      // case every stranded record is in.
      expect(doc['approvalStatus'], 'approved');
      expect(doc['reviewedBy'], 'admin-uid');

      final Map<String, Object?> media =
          (await firestore
                  .collection('schools')
                  .doc('school-a')
                  .collection('entries')
                  .doc('old')
                  .collection('media')
                  .doc('photo')
                  .get())
              .data() ??
          <String, Object?>{};
      expect(media['data'], isA<String>());
    });

    test('it is not picked up a second time', () async {
      await seedStrandedEntry();
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await sync.syncNow(schoolId: 'school-a');
      expect(
        await students.needingPhotoBackfill(),
        isEmpty,
        reason: 're-encoding and re-sending every pass would burn quota daily',
      );
    });

    /// The state the two real cards on the client's phone were actually in.
    ///
    /// Not a hypothetical: a photo failure marks the row `failed`, eight
    /// retries against a bucket that does not exist park it, and the v8
    /// migration only stamped `detailsSyncedAt` on rows that finished
    /// `synced`. So the record WAS at the office and the row had no idea.
    Future<void> seedParkedEntry() async {
      final DateTime then = DateTime(2026, 9, 13);

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('parked')
          .set(<String, Object?>{
            'schoolId': 'school-a',
            'name': 'ATUL',
            'approvalStatus': 'approved',
            'reviewedBy': 'admin-uid',
            'createdAt': then.toUtc().toIso8601String(),
            'updatedAt': then.toUtc().toIso8601String(),
          });

      await students.save(
        StudentEntry(
          id: 'parked',
          schoolId: 'school-a',
          name: 'ATUL',
          approvalStatus: ApprovalStatus.approved,
          reviewedBy: 'admin-uid',
          localPhotoPath: photoFile.path,
          syncStatus: SyncStatus.failed,
          syncAttempts: 8,
          syncError: 'Details uploaded, but photo storage is not set up yet.',
          // detailsSyncedAt deliberately null. This is the whole trap.
          createdAt: then,
          updatedAt: then,
        ),
      );
    }

    test('a PARKED row is picked up, not just a settled one', () async {
      await seedParkedEntry();

      expect(
        await students.dueForUpload(),
        isEmpty,
        reason: 'out of retries - the ordinary queue is done with it',
      );
      expect(
        (await students.needingPhotoBackfill()).single.id,
        'parked',
        reason:
            'gating on detailsSyncedAt alone left this row invisible to BOTH '
            'paths, which is as stuck as a record can get',
      );
    });

    test('and its photo is sent, with the missing stamp healed', () async {
      await seedParkedEntry();
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await sync.syncNow(schoolId: 'school-a');

      final Map<String, Object?> doc =
          (await firestore
                  .collection('schools')
                  .doc('school-a')
                  .collection('entries')
                  .doc('parked')
                  .get())
              .data() ??
          <String, Object?>{};

      expect(doc['photoThumb'], isA<String>());
      expect(doc['approvalStatus'], 'approved');
      expect(doc['reviewedBy'], 'admin-uid');

      final StudentEntry after = (await students.findById('parked'))!;
      expect(
        after.detailsReachedServer,
        isTrue,
        reason:
            'confirmed against the server, so the row stops being a special '
            'case from here on',
      );
      expect(after.photoReachedServer, isTrue);
    });

    test(
      'a parked row whose record never landed gets NO photo-only document',
      () async {
        // Nothing seeded into Firestore: the details never made it. Merging a
        // photoThumb would CREATE the document - a student with a face and no
        // name, sitting in the review queue.
        await students.save(
          StudentEntry(
            id: 'never-landed',
            schoolId: 'school-a',
            name: 'GHOST',
            localPhotoPath: photoFile.path,
            syncStatus: SyncStatus.failed,
            syncAttempts: 8,
            createdAt: DateTime(2026, 9, 13),
            updatedAt: DateTime(2026, 9, 13),
          ),
        );

        final SyncService sync = build();
        addTearDown(sync.dispose);
        await sync.syncNow(schoolId: 'school-a');

        expect(
          (await firestore
                  .collection('schools')
                  .doc('school-a')
                  .collection('entries')
                  .doc('never-landed')
                  .get())
              .exists,
          isFalse,
          reason: 'the backfill must never conjure a record into existence',
        );
      },
    );

    test(
      'a row whose details never synced is left to the normal queue',
      () async {
        await students.save(
          StudentEntry(
            id: 'fresh',
            schoolId: 'school-a',
            name: 'NEW ONE',
            localPhotoPath: photoFile.path,
            createdAt: DateTime(2026, 9, 16),
            updatedAt: DateTime(2026, 9, 16),
          ),
        );

        expect(
          await students.needingPhotoBackfill(),
          isEmpty,
          reason: 'the office has no record to attach a photo to yet',
        );
      },
    );
  });

  group('Bringing a photo down to a device that never took it', () {
    late AppDatabase db;
    late StudentRepository students;
    late SchoolRepository schools;
    late FakeFirebaseFirestore firestore;
    late _FakeConnectivity connectivity;
    late Directory tempDir;
    late PhotoStorage photos;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      students = StudentRepository(db);
      schools = SchoolRepository(db);
      firestore = FakeFirebaseFirestore();
      connectivity = _FakeConnectivity();
      tempDir = Directory.systemTemp.createTempSync('id_entity_download_test');
      photos = PhotoStorage(baseDirectory: tempDir);

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => <ConnectivityResult>[ConnectivityResult.wifi]);
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());
    });

    tearDown(() async {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      await db.close();
    });

    SyncService build() => SyncService(
      students: students,
      schools: schools,
      firestore: firestore,
      connectivity: connectivity,
      isFirebaseReady: () => true,
      photoStorage: photos,
    );

    /// A record as it looks on the admin's device: pulled down from the
    /// server, complete, and with no photo file anywhere on this machine.
    Future<void> seedDownloadedEntry({bool withMedia = true}) async {
      final DateTime then = DateTime(2026, 9, 18);

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('remote')
          .set(<String, Object?>{
            'schoolId': 'school-a',
            'name': 'TEJASWINI DASH',
            'approvalStatus': 'approved',
            'photoThumb': 'VEhVTUI=',
            'createdAt': then.toUtc().toIso8601String(),
            'updatedAt': then.toUtc().toIso8601String(),
          });

      if (withMedia) {
        await firestore
            .collection('schools')
            .doc('school-a')
            .collection('entries')
            .doc('remote')
            .collection('media')
            .doc('photo')
            .set(<String, Object?>{
              'data': base64Encode(cardPortrait),
              'contentType': 'image/jpeg',
              'bytes': cardPortrait.length,
            });
      }

      await students.save(
        StudentEntry(
          id: 'remote',
          schoolId: 'school-a',
          name: 'TEJASWINI DASH',
          approvalStatus: ApprovalStatus.approved,
          photoThumb: 'VEhVTUI=',
          syncStatus: SyncStatus.synced,
          detailsSyncedAt: then,
          createdAt: then,
          updatedAt: then,
        ),
      );
    }

    test(
      'a record with a server photo but no local file is picked up',
      () async {
        await seedDownloadedEntry();
        expect((await students.needingPhotoDownload()).single.id, 'remote');
      },
    );

    test('and the bytes land on disk where the renderer looks', () async {
      // The whole point. The card renderer and the imposition service read
      // `localPhotoPath` - a FILE - so until this existed, a photo sitting in
      // Firestore was invisible to them and the admin rendered an empty photo
      // box for every card captured on another device.
      await seedDownloadedEntry();
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('remote'))!;
      expect(after.localPhotoPath, isNotNull);
      expect(File(after.localPhotoPath!).existsSync(), isTrue);
      expect(File(after.localPhotoPath!).readAsBytesSync(), cardPortrait);
    });

    test('it is not downloaded twice', () async {
      await seedDownloadedEntry();
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await sync.syncNow(schoolId: 'school-a');
      expect(
        await students.needingPhotoDownload(),
        isEmpty,
        reason:
            're-fetching an unchanging blob every two minutes is quota '
            'spent for nothing',
      );
    });

    test(
      'a record whose photo never reached the server is left alone',
      () async {
        await students.save(
          StudentEntry(
            id: 'no-photo',
            schoolId: 'school-a',
            name: 'NOBODY',
            syncStatus: SyncStatus.synced,
            createdAt: DateTime(2026, 9, 18),
            updatedAt: DateTime(2026, 9, 18),
          ),
        );
        expect(await students.needingPhotoDownload(), isEmpty);
      },
    );

    test('a missing media document does not strand the row', () async {
      // The entry advertises a thumbnail but the frame is gone. It must not
      // be written as an empty file, and it must stay eligible so a later
      // pass can still succeed.
      await seedDownloadedEntry(withMedia: false);
      final SyncService sync = build();
      addTearDown(sync.dispose);

      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('remote'))!;
      expect(after.localPhotoPath, isNull);
      expect((await students.needingPhotoDownload()).single.id, 'remote');
    });

    test("a device's own capture is never overwritten", () async {
      // An operator's own photo is already the best copy. Re-downloading over
      // it would replace a local original with a re-encoded round trip.
      await seedDownloadedEntry();
      await students.setLocalPhotoPath('remote', '/device/photos/mine.png');

      expect(await students.needingPhotoDownload(), isEmpty);
    });
  });

  group('Review decisions coming back down to the operator', () {
    late AppDatabase db;
    late StudentRepository students;
    late SchoolRepository schools;
    late FakeFirebaseFirestore firestore;
    late _FakeConnectivity connectivity;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      students = StudentRepository(db);
      schools = SchoolRepository(db);
      firestore = FakeFirebaseFirestore();
      connectivity = _FakeConnectivity();

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => <ConnectivityResult>[ConnectivityResult.wifi]);
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());
    });

    tearDown(() async => db.close());

    SyncService build() => SyncService(
      students: students,
      schools: schools,
      firestore: firestore,
      connectivity: connectivity,
      isFirebaseReady: () => true,
    );

    test('an approval made in the office reaches the teacher', () async {
      // Before this, sync was one-way for an operator: they pushed cards up and
      // never learned what happened to them. That held together only while the
      // admin reviewed from the Flutter panel on the same device - the same
      // local database, so the decision was already there. The moment reviewing
      // moved to the web panel, "sent back for a correction" stopped reaching
      // the person who has to make the correction.
      final DateTime then = DateTime(2026, 9, 14);

      await students.save(
        StudentEntry(
          id: 'e1',
          schoolId: 'school-a',
          name: 'ATUL',
          syncStatus: SyncStatus.synced,
          detailsSyncedAt: then,
          createdAt: then,
          updatedAt: then,
        ),
      );

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('e1')
          .set(<String, Object?>{
            'schoolId': 'school-a',
            'name': 'ATUL',
            'approvalStatus': 'rejected',
            'rejectionReason': 'Photo too dark',
            'createdAt': then.toUtc().toIso8601String(),
            'updatedAt': then.toUtc().toIso8601String(),
          });

      final SyncService sync = build();
      addTearDown(sync.dispose);
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(after.approvalStatus, ApprovalStatus.rejected);
      expect(after.rejectionReason, 'Photo too dark');
    });

    test('but never at the cost of work that has not uploaded', () async {
      final DateTime then = DateTime(2026, 9, 14);

      // Edited on the device and not yet pushed. The local copy is the only
      // copy of this edit.
      await students.save(
        StudentEntry(
          id: 'e1',
          schoolId: 'school-a',
          name: 'CORRECTED NAME',
          syncStatus: SyncStatus.pending,
          createdAt: then,
          updatedAt: then,
        ),
      );

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('e1')
          .set(<String, Object?>{
            'schoolId': 'school-a',
            'name': 'OLD NAME',
            'approvalStatus': 'pending',
            'createdAt': then.toUtc().toIso8601String(),
            'updatedAt': then.toUtc().toIso8601String(),
          });

      final SyncService sync = build();
      addTearDown(sync.dispose);
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(
        after.name,
        'CORRECTED NAME',
        reason: 'the pull must never overwrite an un-uploaded local edit',
      );
    });

    test('a device-local photo path survives the pull', () async {
      final DateTime then = DateTime(2026, 9, 14);

      await students.save(
        StudentEntry(
          id: 'e1',
          schoolId: 'school-a',
          name: 'ATUL',
          localPhotoPath: '/device/photos/e1.png',
          syncStatus: SyncStatus.synced,
          detailsSyncedAt: then,
          createdAt: then,
          updatedAt: then,
        ),
      );

      await firestore
          .collection('schools')
          .doc('school-a')
          .collection('entries')
          .doc('e1')
          .set(<String, Object?>{
            'schoolId': 'school-a',
            'name': 'ATUL',
            'approvalStatus': 'approved',
            'createdAt': then.toUtc().toIso8601String(),
            'updatedAt': then.toUtc().toIso8601String(),
          });

      final SyncService sync = build();
      addTearDown(sync.dispose);
      await sync.syncNow(schoolId: 'school-a');

      final StudentEntry after = (await students.findById('e1'))!;
      expect(
        after.localPhotoPath,
        '/device/photos/e1.png',
        reason:
            'the path means nothing on the server; dropping it would blank '
            "the operator's own thumbnails",
      );
      expect(after.approvalStatus, ApprovalStatus.approved);
    });
  });
}
