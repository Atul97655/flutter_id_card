import 'package:drift/drift.dart';
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

  Future<void> markSyncing(String id) => _patchSync(
        id,
        const StudentEntriesCompanion(syncStatus: Value<String>('syncing')),
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
      ),
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
        bloodGroup: row.bloodGroup,
        dob: row.dob,
        mobile: row.mobile,
        address: row.address,
        localPhotoPath: row.localPhotoPath,
        remotePhotoUrl: row.remotePhotoUrl,
        syncStatus: SyncStatus.fromName(row.syncStatus),
        syncAttempts: row.syncAttempts,
        syncError: row.syncError,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  static StudentEntriesCompanion _toCompanion(StudentEntry e) => StudentEntriesCompanion(
        id: Value<String>(e.id),
        schoolId: Value<String>(e.schoolId),
        name: Value<String>(e.name),
        fatherName: Value<String>(e.fatherName),
        studentClass: Value<String>(e.studentClass),
        division: Value<String>(e.division),
        bloodGroup: Value<String>(e.bloodGroup),
        dob: Value<DateTime?>(e.dob),
        mobile: Value<String>(e.mobile),
        address: Value<String>(e.address),
        localPhotoPath: Value<String?>(e.localPhotoPath),
        remotePhotoUrl: Value<String?>(e.remotePhotoUrl),
        syncStatus: Value<String>(e.syncStatus.name),
        syncAttempts: Value<int>(e.syncAttempts),
        syncError: Value<String?>(e.syncError),
        createdAt: Value<DateTime>(e.createdAt),
        updatedAt: Value<DateTime>(e.updatedAt),
      );
}
