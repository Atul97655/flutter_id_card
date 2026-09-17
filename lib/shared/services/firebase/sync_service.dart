import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/services/firebase/inline_photo.dart';
import 'package:flutter_id_card/shared/services/local/audit_repository.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';

/// What the sync worker is doing right now, for the UI to display.
enum SyncActivity { idle, uploading, downloading, offline, disabled }

/// A snapshot of sync state, exposed to the UI.
class SyncState {
  const SyncState({
    this.activity = SyncActivity.idle,
    this.lastSuccessAt,
    this.lastError,
    this.uploadedThisRun = 0,
    this.pendingCount = 0,
  });

  final SyncActivity activity;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int uploadedThisRun;
  final int pendingCount;

  bool get isBusy =>
      activity == SyncActivity.uploading ||
      activity == SyncActivity.downloading;

  SyncState copyWith({
    SyncActivity? activity,
    DateTime? lastSuccessAt,
    String? lastError,
    bool clearError = false,
    int? uploadedThisRun,
    int? pendingCount,
  }) {
    return SyncState(
      activity: activity ?? this.activity,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      uploadedThisRun: uploadedThisRun ?? this.uploadedThisRun,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// Moves data between the local database and Firebase, in both directions.
///
/// UP: student entries the operator captured (photo to Storage, document to
/// Firestore), plus admin review decisions.
/// DOWN: the school's settings document, so field toggles and branding set in
/// the admin panel reach the operator's device.
///
/// Design constraints this is built around:
///
///   * **Local is the source of truth for un-uploaded work.** Nothing is
///     deleted locally on upload; the row is marked synced. If the server copy
///     is later lost, the device still has it.
///   * **Idempotent.** Uploads use the entry's own id as the Firestore document
///     id, so replaying an interrupted run overwrites rather than duplicating.
///     A duplicate student would be discovered only at the printer.
///   * **Bounded retries with backoff.** A permanently bad row (say, a photo
///     file the OS deleted) must not spin forever burning quota and battery.
///     After [_maxAttempts] it parks as failed until the operator retries by
///     hand from the Sync Status screen.
///   * **Never throws into the UI.** Sync runs in the background; failures are
///     recorded on the row and surfaced as state, not as exceptions.
class SyncService {
  SyncService({
    required StudentRepository students,
    required SchoolRepository schools,
    AuditRepository? auditRepo,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Connectivity? connectivity,
    bool Function()? isFirebaseReady,
  }) : _firestoreOverride = firestore,
       _storageOverride = storage,
       _connectivity = connectivity ?? Connectivity(),
       _isFirebaseReady =
           isFirebaseReady ?? (() => FirebaseBootstrap.instance.isReady),
       // ignore: prefer_initializing_formals
       _students = students,
       // ignore: prefer_initializing_formals
       _schools = schools,
       // ignore: prefer_initializing_formals
       _auditRepo = auditRepo;

  final StudentRepository _students;
  final SchoolRepository _schools;
  final AuditRepository? _auditRepo;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;
  final Connectivity _connectivity;

  /// Whether Firebase has finished starting up.
  ///
  /// Injected rather than read straight off the singleton so this class can be
  /// exercised against a fake Firestore. Without a seam here every test would
  /// short-circuit at the readiness gate and the whole sync worker - the part
  /// of the app that moves a day of captured work off a device - would stay
  /// untestable.
  final bool Function() _isFirebaseReady;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _bucket => _storageOverride ?? FirebaseStorage.instance;

  /// Stop retrying a row after this many failures. Eight attempts with the
  /// backoff below spans roughly half an hour of real time - long enough to
  /// ride out a flaky connection, short enough not to hammer a genuinely
  /// broken row all day.
  static const int _maxAttempts = 8;

  /// How many entries to upload per pass. Small batches keep each run short so
  /// the worker can react to the app being backgrounded mid-sync.
  static const int _batchSize = 10;

  /// Idle interval between automatic passes.
  static const Duration _pollInterval = Duration(minutes: 2);

  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  Stream<SyncState> get stateStream => _stateController.stream;

  SyncState _state = const SyncState();
  SyncState get state => _state;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _running = false;
  bool _started = false;

  /// Begins periodic syncing and syncs immediately.
  ///
  /// Two modes, because the two roles need opposite things:
  ///
  ///   * **Operator** ([schoolId] set): pulls just their own school's settings
  ///     and pushes the entries they captured.
  ///   * **Admin** ([isAdmin] true): pulls *every* school and *every* entry
  ///     down so the dashboard, review queue and print screens have data to
  ///     work with, and pushes review decisions back up. An admin captures
  ///     nothing themselves, so the upload queue is normally just approvals.
  ///
  /// Also listens for connectivity changes: coming back online is the single
  /// best moment to drain the queue, far better than waiting out the poll
  /// interval while the operator watches a "Pending" badge.
  Future<void> start({String? schoolId, bool isAdmin = false}) async {
    if (_started) return;
    _started = true;

    _connectivitySub = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final bool online = results.any(
        (ConnectivityResult r) => r != ConnectivityResult.none,
      );
      if (online) {
        unawaited(syncNow(schoolId: schoolId, isAdmin: isAdmin));
      }
    });

    _timer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(syncNow(schoolId: schoolId, isAdmin: isAdmin)),
    );

    await syncNow(schoolId: schoolId, isAdmin: isAdmin);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }

  void _emit(SyncState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  /// Runs one full pass: pull settings down, push entries up.
  ///
  /// Safe to call concurrently - overlapping calls are collapsed, because two
  /// passes uploading the same row would both mark it syncing and race.
  Future<void> syncNow({String? schoolId, bool isAdmin = false}) async {
    if (_running) return;

    if (!_isFirebaseReady()) {
      _emit(_state.copyWith(activity: SyncActivity.disabled));
      return;
    }

    final List<ConnectivityResult> conn = await _connectivity
        .checkConnectivity();
    if (conn.every((ConnectivityResult r) => r == ConnectivityResult.none)) {
      _emit(_state.copyWith(activity: SyncActivity.offline));
      return;
    }

    _running = true;
    try {
      _emit(
        _state.copyWith(activity: SyncActivity.downloading, clearError: true),
      );
      if (isAdmin) {
        await _pullEverythingForAdmin();
      } else if (schoolId != null) {
        await _pullSchoolConfig(schoolId);
        await _pullSchoolEntries(schoolId);
      }

      _emit(_state.copyWith(activity: SyncActivity.uploading));
      final int uploaded = await _pushEntries();
      await _backfillPhotos();

      final List<StudentEntry> stillPending = await _students.dueForUpload(
        limit: 1000,
        maxAttempts: _maxAttempts,
      );

      if (_auditRepo != null && (uploaded > 0 || stillPending.isNotEmpty)) {
        await _auditRepo.log(
          action: 'sync_pass',
          entityType: 'sync',
          entityId: schoolId ?? (isAdmin ? 'admin' : 'all'),
          actorUid: isAdmin ? 'admin' : (schoolId ?? 'sync_worker'),
          details: <String, Object?>{
            'uploaded': uploaded,
            'stillPending': stillPending.length,
            'isAdmin': isAdmin,
            'schoolId': schoolId,
          },
        );
      }

      _emit(
        _state.copyWith(
          activity: SyncActivity.idle,
          lastSuccessAt: DateTime.now(),
          uploadedThisRun: uploaded,
          pendingCount: stillPending.length,
          clearError: true,
        ),
      );
    } on Object catch (e) {
      // A pass-level failure (not a per-row one) - typically the settings
      // fetch. Individual row failures are recorded on the rows themselves.
      _emit(
        _state.copyWith(activity: SyncActivity.idle, lastError: e.toString()),
      );
      if (kDebugMode) debugPrint('Sync pass failed: $e');
    } finally {
      _running = false;
    }
  }

  // ------------------------------------------------------------------
  // Down: school settings
  // ------------------------------------------------------------------

  /// Caches the school's settings document locally.
  ///
  /// Without this the operator's form would fall back to showing every field
  /// with a placeholder school name, because the app deliberately reads
  /// settings from the local database rather than the network - that is what
  /// lets it work offline.
  Future<void> _pullSchoolConfig(String schoolId) async {
    if (schoolId.isEmpty) return;

    final DocumentSnapshot<Map<String, Object?>> snap = await _db
        .collection('schools')
        .doc(schoolId)
        .get();

    if (!snap.exists) return;

    final SchoolConfig remote = SchoolConfig.fromFirestoreMap(
      snap.id,
      snap.data() ?? <String, Object?>{},
    );

    // Preserve the locally cached logo path: it is a device-local file path and
    // has no meaning on the server, so a naive overwrite would blank it and the
    // card would render without a logo until the image was fetched again.
    final SchoolConfig? existing = await _schools.find(schoolId);
    await _schools.save(
      existing?.localLogoPath == null
          ? remote
          : remote.copyWith(localLogoPath: existing!.localLogoPath),
    );
  }

  /// Merges a record fetched from the server onto what this device knows.
  ///
  /// [StudentEntry.fromFirestoreMap] builds an entry from the wire format
  /// alone, and several fields are not on the wire at all because they are
  /// this device's own bookkeeping. Writing the bare remote copy over the
  /// local row silently erased them, with two visible consequences: the
  /// progress timeline forgot that a submission had ever reached the office,
  /// and the photo backfill - which finds work by asking "whose details are on
  /// the server but whose photo is not" - stopped finding anything at all,
  /// because every candidate had just had that fact wiped one step earlier in
  /// the same sync pass.
  ///
  /// `detailsSyncedAt` is filled in rather than merely preserved: this record
  /// was just read back from the server, so the details demonstrably reached
  /// it, whatever the local row happened to remember.
  StudentEntry _mergeRemote(StudentEntry remote, StudentEntry? local) {
    return remote.copyWith(
      // Device-local file path. Means nothing on the server; dropping it would
      // blank the operator's own thumbnails and the admin's card previews.
      localPhotoPath: local?.localPhotoPath,
      detailsSyncedAt: local?.detailsSyncedAt ?? remote.updatedAt,
      lastSyncAttemptAt: local?.lastSyncAttemptAt,
      // The server's thumbnail wins when it has one; otherwise keep whatever
      // this device already had rather than blanking a face it can render.
      photoThumb: remote.photoThumb ?? local?.photoThumb,
    );
  }

  /// Brings the office's review decisions back down to the operator.
  ///
  /// Without this the flow is one-way: a teacher submits a card, the admin
  /// approves or returns it, and the teacher's device never finds out. That
  /// held together only while approvals were made from the Flutter admin panel
  /// on the same device - same local database, so the decision was already
  /// there. The moment reviewing moved to the web panel, "sent back for a
  /// correction" stopped reaching the person who has to make the correction.
  ///
  /// Runs BEFORE the upload pass on every operator sync, which also matters
  /// for writes: an entry whose local review state is stale would be pushed
  /// back with the old `approvalStatus`, and the rules correctly refuse an
  /// operator changing a review. Pulling first means the row it pushes agrees
  /// with the server about everything it is not allowed to change.
  Future<void> _pullSchoolEntries(String schoolId) async {
    if (schoolId.isEmpty) return;

    final QuerySnapshot<Map<String, Object?>> docs = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('entries')
        .get();

    final List<StudentEntry> incoming = <StudentEntry>[];
    for (final QueryDocumentSnapshot<Map<String, Object?>> d in docs.docs) {
      final StudentEntry remote = StudentEntry.fromFirestoreMap(d.id, d.data());
      final StudentEntry? local = await _students.findById(d.id);

      // Never clobber work that has not uploaded yet - the local copy is the
      // only copy of it.
      if (local != null && local.syncStatus.needsUpload) continue;

      incoming.add(_mergeRemote(remote, local));
    }
    if (incoming.isNotEmpty) await _students.saveAll(incoming);
  }

  /// Mirrors every school and every entry into the local database.
  ///
  /// The admin panel reads exclusively from local storage, exactly like the
  /// operator side, so the dashboard and review queue keep working on the
  /// office's flaky connection instead of showing spinners over dead network
  /// calls. This is the job that fills it.
  ///
  /// Locally-modified rows are protected: an entry still waiting to upload
  /// (typically an approval the admin just made) is **not** overwritten by the
  /// server copy, which would silently discard the decision.
  Future<void> _pullEverythingForAdmin() async {
    final QuerySnapshot<Map<String, Object?>> schoolDocs = await _db
        .collection('schools')
        .get();

    final List<SchoolConfig> schools = <SchoolConfig>[];
    for (final QueryDocumentSnapshot<Map<String, Object?>> doc
        in schoolDocs.docs) {
      final SchoolConfig remote = SchoolConfig.fromFirestoreMap(
        doc.id,
        doc.data(),
      );
      final SchoolConfig? existing = await _schools.find(doc.id);
      schools.add(
        existing?.localLogoPath == null
            ? remote
            : remote.copyWith(localLogoPath: existing!.localLogoPath),
      );
    }
    if (schools.isNotEmpty) await _schools.saveAll(schools);

    // Entries, school by school. A collectionGroup query would be one round
    // trip instead of N, but it needs its own composite index and its own
    // security rule; with a handful of schools the simple form is not worth
    // that operational cost.
    for (final QueryDocumentSnapshot<Map<String, Object?>> doc
        in schoolDocs.docs) {
      final QuerySnapshot<Map<String, Object?>> entryDocs = await _db
          .collection('schools')
          .doc(doc.id)
          .collection('entries')
          .get();

      final List<StudentEntry> incoming = <StudentEntry>[];
      for (final QueryDocumentSnapshot<Map<String, Object?>> e
          in entryDocs.docs) {
        final StudentEntry remote = StudentEntry.fromFirestoreMap(
          e.id,
          e.data(),
        );
        final StudentEntry? local = await _students.findById(e.id);

        // Never clobber work that has not uploaded yet.
        if (local != null && local.syncStatus.needsUpload) continue;

        incoming.add(_mergeRemote(remote, local));
      }
      if (incoming.isNotEmpty) await _students.saveAll(incoming);
    }
  }

  // ------------------------------------------------------------------
  // Up: student entries
  // ------------------------------------------------------------------

  Future<int> _pushEntries() async {
    // Reset entries that got stuck in 'syncing' for > 10 min back to 'pending'
    await _students.resetStaleSyncing();

    final List<StudentEntry> due = await _students.dueForUpload(
      limit: _batchSize,
      maxAttempts: _maxAttempts,
    );

    int uploaded = 0;
    for (final StudentEntry entry in due) {
      if (_shouldDelay(entry)) continue;

      final bool ok = await _uploadOne(entry);
      if (ok) uploaded++;
    }
    return uploaded;
  }

  /// Exponential backoff between retries of the same row: roughly 2s, 4s, 8s,
  /// ... capped at 5 minutes. Without this, a row that fails instantly would
  /// be retried on every pass and dominate the batch.
  ///
  /// Measured from [StudentEntry.lastSyncAttemptAt] - when the worker last
  /// tried - NOT from `updatedAt`, which is when the operator last edited the
  /// row. Reading the edit time made this a no-op: by the time a row had
  /// failed once, its edit time was almost always further in the past than any
  /// backoff window, so the check returned false every time and the "bounded
  /// retries with backoff" this class documents never actually happened.
  bool _shouldDelay(StudentEntry entry) {
    if (entry.syncAttempts == 0) return false;

    // No attempt clock means a row written before that column existed. Let it
    // through: one immediate attempt is the safe direction, and the next
    // failure stamps the clock properly.
    final DateTime? lastAttempt = entry.lastSyncAttemptAt;
    if (lastAttempt == null) return false;

    final Duration wait = Duration(
      seconds: math.min(300, math.pow(2, entry.syncAttempts).toInt()),
    );
    return DateTime.now().isBefore(lastAttempt.add(wait));
  }

  /// The document that carries a student's full-resolution photo when it
  /// travels inside Firestore rather than through Cloud Storage.
  DocumentReference<Map<String, Object?>> _photoDoc(StudentEntry entry) => _db
      .collection('schools')
      .doc(entry.schoolId)
      .collection('entries')
      .doc(entry.id)
      .collection('media')
      .doc('photo');

  /// Sends the photo - and only the photo - for records the office already
  /// holds but has no picture for.
  ///
  /// Every submission made before photos could travel inside Firestore is in
  /// this state: the details synced, Cloud Storage refused the picture, and
  /// the row either settled as `synced` or burned through its retries. Neither
  /// is ever looked at again by the ordinary upload queue, so without this
  /// those students stay permanently unprintable and the operator's only
  /// remedy is to retake a photo that was never the problem.
  ///
  /// This writes the media document and merges a single `photoThumb` field
  /// onto the entry. It does not re-send the student's details and it does not
  /// touch the review decision - which is what makes it safe to run against a
  /// record the admin may have approved in the meantime, where re-pushing the
  /// whole document would be refused by the rules.
  ///
  /// **The existence check is not defensive padding.** A parked row has no
  /// reliable local record that its details ever reached the server - the
  /// column that would say so was only ever stamped on rows that finished
  /// `synced` - so the local state cannot answer "is there a document to
  /// attach this photo to". Asking the server is the only honest answer, and
  /// without it a merge would happily *create* a document holding nothing but
  /// a photo: a student with a face and no name, sitting in the review queue.
  ///
  /// Confirming it also heals the missing stamp, so the row stops being a
  /// special case from here on.
  ///
  /// Small batches: encoding is cheap, but each row is a read plus two writes
  /// and there is no hurry - the backlog drains over a few passes.
  Future<int> _backfillPhotos() async {
    final List<StudentEntry> rows = await _students.needingPhotoBackfill(
      maxAttempts: _maxAttempts,
    );
    if (rows.isEmpty) return 0;

    int done = 0;
    for (final StudentEntry entry in rows) {
      final String? path = entry.localPhotoPath;
      if (path == null || path.isEmpty) continue;

      final File file = File(path);
      if (!file.existsSync()) continue;

      try {
        final DocumentReference<Map<String, Object?>> entryDoc = _db
            .collection('schools')
            .doc(entry.schoolId)
            .collection('entries')
            .doc(entry.id);

        // See the note above: without this, a parked row whose details never
        // landed would have a photo-only document created for it.
        if (!(await entryDoc.get()).exists) continue;

        // The details demonstrably are on the server, whatever the local row
        // remembered. Record that now so this row is ordinary from here on.
        if (!entry.detailsReachedServer) {
          await _students.markDetailsSynced(entry.id);
        }

        final InlinePhoto? inline = await encodeInlinePhoto(
          await file.readAsBytes(),
        );
        if (inline == null) continue;

        await _photoDoc(entry).set(<String, Object?>{
          'data': inline.fullBase64,
          'contentType': 'image/jpeg',
          'bytes': inline.fullBytes,
          'width': inline.width,
          'height': inline.height,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });

        await entryDoc.set(<String, Object?>{
          'photoThumb': inline.thumbBase64,
        }, SetOptions(merge: true));

        await _students.markPhotoSynced(entry.id, inline.thumbBase64);
        done++;
      } on Object catch (e) {
        // Never fatal, and never recorded on the row: the record itself is
        // fine and already at the office. A backfill that cannot complete is
        // retried on the next pass and otherwise costs nobody anything.
        if (kDebugMode) debugPrint('Photo backfill failed for ${entry.id}: $e');
      }
    }
    return done;
  }

  Future<bool> _uploadOne(StudentEntry entry) async {
    // Pre-flight check: required fields must be present
    if (entry.name.trim().isEmpty || entry.schoolId.trim().isEmpty) {
      await _students.markFailed(
        entry.id,
        'Pre-flight validation failed: Student name and School ID are required.',
        _maxAttempts,
      );
      return false;
    }

    await _students.markSyncing(entry.id);

    try {
      String? photoUrl = entry.remotePhotoUrl;

      // Why the photo is attempted first, and why its failure is NOT fatal:
      //
      // Uploading it before the document means a document can never point at a
      // photo that failed to land. But an earlier version let a photo failure
      // abort the whole row, which meant that if Storage was unavailable -
      // exactly the case when the bucket has not been provisioned - not a
      // single submission reached the office. The review queue stayed empty
      // and the operator's day of work looked lost.
      //
      // So a photo failure now degrades instead: the student's details still
      // upload with a null photoUrl, the entry appears in the admin queue, and
      // the row stays queued so the photo is retried. The print path already
      // excludes entries without a photo and reports the count, so a card can
      // never be printed with an empty photo box.
      String? photoError;
      InlinePhoto? inline;

      final String? localPath = entry.localPhotoPath;
      final bool needsPhoto =
          photoUrl == null &&
          (entry.photoThumb == null || entry.photoThumb!.isEmpty) &&
          localPath != null &&
          localPath.isNotEmpty;

      if (needsPhoto) {
        final File file = File(localPath);
        if (file.existsSync()) {
          try {
            photoUrl = await _uploadPhoto(entry, file);
          } on FirebaseException catch (e) {
            photoError = _describePhoto(e);
          } on Object catch (e) {
            photoError = 'Photo upload failed: $e';
          }

          // Storage did not take it. Carry the photo in Firestore instead.
          //
          // This is what makes the system work at all on a project without a
          // Storage bucket: before it existed, a Storage failure meant the
          // photo simply never left the device, so the office saw every
          // approved card as unprintable and the only machine that could print
          // a card was the one that took the picture. Firestore is already
          // provisioned and a card portrait re-encodes to a few tens of KB,
          // which fits a document with room to spare.
          if (photoUrl == null) {
            try {
              inline = await encodeInlinePhoto(await file.readAsBytes());
              if (inline != null) photoError = null;
            } on Object catch (e) {
              // Keep the Storage error if there is one - it is the more
              // actionable of the two. This only reports the fallback's own
              // failure when the fallback was the only route tried.
              photoError ??= 'Could not prepare the photo for upload: $e';
            }
          }
        } else {
          // The processed photo is gone from disk - the OS cleared it, or the
          // app was reinstalled. Retrying cannot fix this, so fail it straight
          // to the operator rather than burning all eight attempts.
          await _students.markFailed(
            entry.id,
            'Photo file is missing from this device. Re-capture the photo.',
            _maxAttempts,
          );
          return false;
        }
      }

      // Written before the entry document, so the entry can never advertise a
      // thumbnail whose full frame has not landed. An orphaned media document
      // (entry write fails after this one succeeds) is harmless: the next pass
      // overwrites it.
      if (inline != null) {
        await _photoDoc(entry).set(<String, Object?>{
          'data': inline.fullBase64,
          'contentType': 'image/jpeg',
          'bytes': inline.fullBytes,
          'width': inline.width,
          'height': inline.height,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }

      final StudentEntry toWrite = entry.copyWith(
        remotePhotoUrl: photoUrl,
        photoThumb: inline?.thumbBase64,
      );

      // The entry's own id is the document id, which makes this idempotent:
      // replaying an interrupted run overwrites instead of creating a second
      // record for the same student.
      await _db
          .collection('schools')
          .doc(entry.schoolId)
          .collection('entries')
          .doc(entry.id)
          .set(toWrite.toFirestoreMap(), SetOptions(merge: true));

      // The office has the record from here on, whatever the photo did.
      await _students.markDetailsSynced(entry.id);

      if (photoError != null) {
        // The details are on the server; only the photo is outstanding. Keep
        // the row queued so the photo is retried, and tell the operator which
        // half failed rather than implying the whole submission was lost.
        await _students.markFailed(entry.id, photoError, entry.syncAttempts);
        return false;
      }

      await _students.markSynced(
        entry.id,
        remotePhotoUrl: photoUrl,
        photoThumb: inline?.thumbBase64,
      );
      return true;
    } on FirebaseException catch (e) {
      await _students.markFailed(entry.id, _describe(e), entry.syncAttempts);
      return false;
    } on Object catch (e) {
      await _students.markFailed(entry.id, e.toString(), entry.syncAttempts);
      return false;
    }
  }

  Future<String> _uploadPhoto(StudentEntry entry, File file) async {
    final Reference ref = _bucket
        .ref()
        .child('schools')
        .child(entry.schoolId)
        .child('photos')
        .child('${entry.id}.png');

    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/png',
        // Cache aggressively: a student photo never changes once captured, and
        // the admin panel re-renders the same thumbnails constantly.
        cacheControl: 'public, max-age=31536000',
      ),
    );
    return ref.getDownloadURL();
  }

  /// Photo-upload failures, phrased so the operator knows the student's
  /// details DID reach the office and only the picture is outstanding.
  ///
  /// A missing bucket or object here almost always means Cloud Storage has not
  /// been provisioned on the Firebase project at all, rather than anything the
  /// operator did - so the message points at the office instead of asking them
  /// to retake a photo that is perfectly fine.
  String _describePhoto(FirebaseException e) => switch (e.code) {
    'bucket-not-found' || 'object-not-found' || 'project-not-found' =>
      'Details uploaded, but photo storage is not set up for this school '
          'yet. Tell the office - the photo will upload by itself once it '
          'is. Do not retake it.',
    'unauthorized' || 'permission-denied' =>
      'Details uploaded, but the server rejected the photo. Your account '
          'may not have access to this school.',
    'unauthenticated' => 'Signed out. Sign in again to upload the photo.',
    'quota-exceeded' || 'resource-exhausted' =>
      'Details uploaded. Photo storage is full - tell the office.',
    'retry-limit-exceeded' ||
    'canceled' => 'Details uploaded. The photo did not finish - it will retry.',
    _ =>
      'Details uploaded, but the photo did not: '
          '${e.message ?? e.code}',
  };

  /// Turns Firebase error codes into something an operator can act on.
  String _describe(FirebaseException e) => switch (e.code) {
    // Two very different causes, and the operator can only act on one of
    // them, so both are named. The common one is not an access problem at
    // all: editing a card resets it to "pending review", and the server
    // refuses that if the office has already approved it. The operator's
    // device simply had not learned about the approval yet.
    'permission-denied' =>
      'Server rejected this change. Usually this means the office already '
          'approved this card, so it can no longer be edited - open it to '
          'see its current status. If it is still pending, your account '
          'may not have access to this school.',
    'unavailable' ||
    'deadline-exceeded' => 'Server unreachable. Will retry automatically.',
    'unauthenticated' => 'Signed out. Sign in again to upload.',
    'resource-exhausted' => 'Server quota exceeded. Will retry later.',
    _ => e.message ?? 'Upload failed (${e.code}).',
  };
}

/// Fire-and-forget without pulling in `package:async` for one call.
void unawaited(Future<void> future) => future.ignore();
