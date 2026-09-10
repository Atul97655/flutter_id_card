import 'package:drift/drift.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';

/// All persistence for student entries.
///
/// Widgets never touch Drift directly; they go through this class via Riverpod
/// providers. Everything here writes locally and returns immediately - network
/// work is the sync service's job.
class StudentRepository {
  StudentRepository(this._db);

  final AppDatabase _db;

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  /// Live list for the "Saved Entries" screen, newest first.
  Stream<List<StudentEntry>> watchBySchool(String schoolId) {
    final SimpleSelectStatement<StudentEntries, StudentEntryRow> query =
        _db.select(_db.studentEntries)
          ..where((StudentEntries t) => t.schoolId.equals(schoolId))
          ..orderBy(<OrderClauseGenerator<StudentEntries>>[
            (StudentEntries t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]);
    return query.watch().map(
          (List<StudentEntryRow> rows) => rows.map(_toDomain).toList(),
        );
  }

  Future<List<StudentEntry>> listBySchool(String schoolId) async {
    final List<StudentEntryRow> rows = await (_db.select(_db.studentEntries)
          ..where((StudentEntries t) => t.schoolId.equals(schoolId))
          ..orderBy(<OrderClauseGenerator<StudentEntries>>[
            (StudentEntries t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<StudentEntry?> findById(String id) async {
    final StudentEntryRow? row = await (_db.select(_db.studentEntries)
          ..where((StudentEntries t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Rows the sync worker should attempt, oldest first so the backlog drains
  /// in the order it was created.
  Future<List<StudentEntry>> dueForUpload({int limit = 20, int maxAttempts = 8}) async {
    final List<StudentEntryRow> rows = await (_db.select(_db.studentEntries)
          ..where(
            (StudentEntries t) =>
                t.syncStatus.isIn(<String>['pending', 'failed']) &
                t.syncAttempts.isSmallerThanValue(maxAttempts),
          )
          ..orderBy(<OrderClauseGenerator<StudentEntries>>[
            (StudentEntries t) => OrderingTerm(expression: t.createdAt),
          ])
          ..limit(limit))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Counts per status, for the Sync Status screen's summary tiles.
  Stream<Map<SyncStatus, int>> watchStatusCounts(String schoolId) {
    return watchBySchool(schoolId).map((List<StudentEntry> entries) {
      final Map<SyncStatus, int> counts = <SyncStatus, int>{
        for (final SyncStatus s in SyncStatus.values) s: 0,
      };
      for (final StudentEntry e in entries) {
        counts[e.syncStatus] = (counts[e.syncStatus] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ------------------------------------------------------------------
  // Writes
  // ------------------------------------------------------------------

  /// Insert-or-replace. Used by both "new entry" and "edit existing".
  Future<void> save(StudentEntry entry) async {
    await _db
        .into(_db.studentEntries)
        .insertOnConflictUpdate(_toCompanion(entry));
  }

  Future<void> saveAll(List<StudentEntry> entries) async {
    await _db.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        _db.studentEntries,
        entries.map(_toCompanion).toList(),
      );
    });
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.studentEntries)
          ..where((StudentEntries t) => t.id.equals(id)))
        .go();
  }

  /// Marks an upload as in flight and stamps the attempt clock, which is what
  /// [resetStaleSyncing] measures against.
  Future<void> markSyncing(String id) => _patchSync(
        id,
        StudentEntriesCompanion(
          syncStatus: const Value<String>('syncing'),
          lastSyncAttemptAt: Value<DateTime?>(DateTime.now()),
        ),
      );

  Future<void> markSynced(String id, {String? remotePhotoUrl}) => _patchSync(
        id,
        StudentEntriesCompanion(
          syncStatus: const Value<String>('synced'),
          syncError: const Value<String?>(null),
          remotePhotoUrl:
              remotePhotoUrl == null ? const Value<String?>.absent() : Value<String?>(remotePhotoUrl),
        ),
      );

  /// Records a failure and increments the attempt counter, which drives the
  /// retry backoff and eventually parks the record so it stops burning quota.
  Future<void> markFailed(String id, String error, int previousAttempts) => _patchSync(
        id,
        StudentEntriesCompanion(
          syncStatus: const Value<String>('failed'),
          syncError: Value<String?>(error),
          syncAttempts: Value<int>(previousAttempts + 1),
          // Stamped so the backoff measures from this failure rather than from
          // whenever the operator last edited the row.
          lastSyncAttemptAt: Value<DateTime?>(DateTime.now()),
        ),
      );

  /// Clears the attempt counter on records the operator explicitly retries, so
  /// a manual "Retry all" is not blocked by the maxAttempts ceiling.
  Future<void> resetFailures(String schoolId) async {
    await (_db.update(_db.studentEntries)
          ..where(
            (StudentEntries t) =>
                t.schoolId.equals(schoolId) & t.syncStatus.equals('failed'),
          ))
        .write(
      const StudentEntriesCompanion(
        syncStatus: Value<String>('pending'),
        syncAttempts: Value<int>(0),
        syncError: Value<String?>(null),
        // Cleared so an explicit retry is attempted at once instead of sitting
        // out the backoff from the failure the operator just reacted to.
        lastSyncAttemptAt: Value<DateTime?>(null),
      ),
    );
  }

  /// Resets entries stuck in 'syncing' for more than [olderThan] (default 10 min)
  /// back to 'pending'.
  ///
  /// Measures `lastSyncAttemptAt`, not `updatedAt`. Using the edit time meant a
  /// row edited over ten minutes ago looked stuck the instant it started
  /// uploading, so a genuinely in-flight upload could be reset and sent twice.
  /// A row with no attempt clock at all is treated as stuck: it can only get
  /// into that state from a build before this column existed.
  Future<int> resetStaleSyncing({
    Duration olderThan = const Duration(minutes: 10),
  }) async {
    final DateTime threshold = DateTime.now().subtract(olderThan);
    return (_db.update(_db.studentEntries)
          ..where(
            (StudentEntries t) =>
                t.syncStatus.equals('syncing') &
                (t.lastSyncAttemptAt.isSmallerThanValue(threshold) |
                    t.lastSyncAttemptAt.isNull()),
          ))
        .write(
      const StudentEntriesCompanion(
        syncStatus: Value<String>('pending'),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Review (admin approval workflow)
  // ------------------------------------------------------------------

  /// Records an admin's approval. Also puts the row back in the upload queue so
  /// the decision itself propagates to Firestore - the approval is data like
  /// any other and is worthless if it only ever lives on the admin's device.
  Future<void> approve(String id, {required String reviewerUid}) async {
    await (_db.update(_db.studentEntries)
          ..where((StudentEntries t) => t.id.equals(id)))
        .write(
      StudentEntriesCompanion(
        approvalStatus: const Value<String>('approved'),
        rejectionReason: const Value<String?>(null),
        reviewedBy: Value<String?>(reviewerUid),
        reviewedAt: Value<DateTime?>(DateTime.now()),
        syncStatus: const Value<String>('pending'),
        syncAttempts: const Value<int>(0),
      ),
    );
  }

  /// Records a rejection with the reason the operator will see.
  Future<void> reject(
    String id, {
    required String reviewerUid,
    required String reason,
  }) async {
    await (_db.update(_db.studentEntries)
          ..where((StudentEntries t) => t.id.equals(id)))
        .write(
      StudentEntriesCompanion(
        approvalStatus: const Value<String>('rejected'),
        rejectionReason: Value<String?>(reason),
        reviewedBy: Value<String?>(reviewerUid),
        reviewedAt: Value<DateTime?>(DateTime.now()),
        syncStatus: const Value<String>('pending'),
        syncAttempts: const Value<int>(0),
      ),
    );
  }

  /// Marks every entry that went into a print run as printed.
  ///
  /// Called by the print screen after a batch is written, never chosen by hand.
  /// Only `approved` rows move: a row that is somehow still pending must not be
  /// promoted straight to printed, and a row already printed does not need its
  /// review timestamp rewritten on every reprint.
  ///
  /// Like [approve], this re-queues the rows for sync so the teacher's device
  /// learns their cards were printed.
  Future<int> markPrinted(List<String> ids) async {
    if (ids.isEmpty) return 0;
    return (_db.update(_db.studentEntries)
          ..where(
            (StudentEntries t) =>
                t.id.isIn(ids) & t.approvalStatus.equals('approved'),
          ))
        .write(
      const StudentEntriesCompanion(
        approvalStatus: Value<String>('printed'),
        syncStatus: Value<String>('pending'),
        syncAttempts: Value<int>(0),
      ),
    );
  }

  /// Bulk approve, for an admin clearing a whole class at once. Runs as one
  /// batch so a hundred-row approval is a single database round trip.
  Future<void> approveAll(
    List<String> ids, {
    required String reviewerUid,
  }) async {
    if (ids.isEmpty) return;
    final DateTime now = DateTime.now();
    await _db.batch((Batch batch) {
      batch.update(
        _db.studentEntries,
        StudentEntriesCompanion(
          approvalStatus: const Value<String>('approved'),
          rejectionReason: const Value<String?>(null),
          reviewedBy: Value<String?>(reviewerUid),
          reviewedAt: Value<DateTime?>(now),
          syncStatus: const Value<String>('pending'),
          syncAttempts: const Value<int>(0),
        ),
        where: (StudentEntries t) => t.id.isIn(ids),
      );
    });
  }

  /// Bulk reject with mandatory rejection reason.
  Future<void> rejectAll(
    List<String> ids, {
    required String reviewerUid,
    required String reason,
  }) async {
    if (ids.isEmpty) return;
    final DateTime now = DateTime.now();
    await _db.batch((Batch batch) {
      batch.update(
        _db.studentEntries,
        StudentEntriesCompanion(
          approvalStatus: const Value<String>('rejected'),
          rejectionReason: Value<String?>(reason),
          reviewedBy: Value<String?>(reviewerUid),
          reviewedAt: Value<DateTime?>(now),
          syncStatus: const Value<String>('pending'),
          syncAttempts: const Value<int>(0),
        ),
        where: (StudentEntries t) => t.id.isIn(ids),
      );
    });
  }

  /// Checks if any existing student has the same name and class in the given school.
  Future<List<StudentEntry>> findPotentialDuplicates({
    required String schoolId,
    required String name,
    required String studentClass,
    DateTime? dob,
    String? excludeId,
  }) async {
    final List<StudentEntry> schoolStudents = await listBySchool(schoolId);
    final String cleanName = name.trim().toUpperCase();
    final String cleanClass = studentClass.trim().toUpperCase();

    return schoolStudents.where((StudentEntry e) {
      if (excludeId != null && e.id == excludeId) return false;
      if (e.name.trim().toUpperCase() != cleanName) return false;
      if (cleanClass.isNotEmpty &&
          e.studentClass.trim().toUpperCase() != cleanClass) {
        return false;
      }
      if (dob != null && e.dob != null) {
        return e.dob!.year == dob.year &&
            e.dob!.month == dob.month &&
            e.dob!.day == dob.day;
      }
      return true;
    }).toList();
  }

  /// Entries eligible for a print run: approved, and carrying a photo.
  ///
  /// Both conditions matter. Approval is the human gate; the photo check stops
  /// a card with an empty photo box reaching a 25-up sheet, which wastes the
  /// whole sheet.
  Future<List<StudentEntry>> printableForSchool(String schoolId) async {
    final List<StudentEntryRow> rows = await (_db.select(_db.studentEntries)
          ..where(
            (StudentEntries t) =>
                t.schoolId.equals(schoolId) &
                t.approvalStatus.equals('approved'),
          )
          ..orderBy(<OrderClauseGenerator<StudentEntries>>[
            (StudentEntries t) => OrderingTerm(expression: t.studentClass),
            (StudentEntries t) => OrderingTerm(expression: t.division),
            (StudentEntries t) => OrderingTerm(expression: t.name),
          ]))
        .get();

    return rows
        .map(_toDomain)
        .where((StudentEntry e) => e.hasPhoto)
        .toList();
  }

  /// Live review queue for the admin dashboard, newest first.
  Stream<List<StudentEntry>> watchByApproval(
    String schoolId,
    ApprovalStatus status,
  ) {
    final SimpleSelectStatement<StudentEntries, StudentEntryRow> query =
        _db.select(_db.studentEntries)
          ..where(
            (StudentEntries t) =>
                t.schoolId.equals(schoolId) &
                t.approvalStatus.equals(status.name),
          )
          ..orderBy(<OrderClauseGenerator<StudentEntries>>[
            (StudentEntries t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]);
    return query.watch().map(
          (List<StudentEntryRow> rows) => rows.map(_toDomain).toList(),
        );
  }

  /// Every entry across all schools - the admin dashboard's global view.
  Stream<List<StudentEntry>> watchAll() {
    final SimpleSelectStatement<StudentEntries, StudentEntryRow> query =
        _db.select(_db.studentEntries)
          ..orderBy(<OrderClauseGenerator<StudentEntries>>[
            (StudentEntries t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]);
    return query.watch().map(
          (List<StudentEntryRow> rows) => rows.map(_toDomain).toList(),
        );
  }

  Future<void> _patchSync(String id, StudentEntriesCompanion patch) async {
    await (_db.update(_db.studentEntries)
          ..where((StudentEntries t) => t.id.equals(id)))
        .write(patch);
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  static StudentEntry _toDomain(StudentEntryRow row) => StudentEntry(
        id: row.id,
        schoolId: row.schoolId,
        name: row.name,
        fatherName: row.fatherName,
        studentClass: row.studentClass,
        division: row.division,
        rollNumber: row.rollNumber,
        bloodGroup: row.bloodGroup,
        dob: row.dob,
        mobile: row.mobile,
        address: row.address,
        localPhotoPath: row.localPhotoPath,
        remotePhotoUrl: row.remotePhotoUrl,
        syncStatus: SyncStatus.fromName(row.syncStatus),
        syncAttempts: row.syncAttempts,
        syncError: row.syncError,
        approvalStatus: ApprovalStatus.fromName(row.approvalStatus),
        rejectionReason: row.rejectionReason,
        reviewedBy: row.reviewedBy,
        reviewedAt: row.reviewedAt,
        createdAt: row.createdAt,
        lastSyncAttemptAt: row.lastSyncAttemptAt,
        updatedAt: row.updatedAt,
      );

  static StudentEntriesCompanion _toCompanion(StudentEntry e) => StudentEntriesCompanion(
        id: Value<String>(e.id),
        schoolId: Value<String>(e.schoolId),
        name: Value<String>(e.name),
        fatherName: Value<String>(e.fatherName),
        studentClass: Value<String>(e.studentClass),
        division: Value<String>(e.division),
        rollNumber: Value<String>(e.rollNumber),
        bloodGroup: Value<String>(e.bloodGroup),
        dob: Value<DateTime?>(e.dob),
        mobile: Value<String>(e.mobile),
        address: Value<String>(e.address),
        localPhotoPath: Value<String?>(e.localPhotoPath),
        remotePhotoUrl: Value<String?>(e.remotePhotoUrl),
        syncStatus: Value<String>(e.syncStatus.name),
        syncAttempts: Value<int>(e.syncAttempts),
        syncError: Value<String?>(e.syncError),
        approvalStatus: Value<String>(e.approvalStatus.name),
        rejectionReason: Value<String?>(e.rejectionReason),
        reviewedBy: Value<String?>(e.reviewedBy),
        reviewedAt: Value<DateTime?>(e.reviewedAt),
        createdAt: Value<DateTime>(e.createdAt),
        lastSyncAttemptAt: Value<DateTime?>(e.lastSyncAttemptAt),
        updatedAt: Value<DateTime>(e.updatedAt),
      );
}
