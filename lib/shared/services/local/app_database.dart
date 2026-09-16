import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Local SQLite store. This is the **primary** store for the data-entry app:
/// every entry is committed here before any network call is attempted, so the
/// operator can work a full day with no connectivity and lose nothing.
///
/// Generated data classes are suffixed `Row` to keep them distinct from the
/// domain models in `shared/models` - the repository maps between the two.

@DataClassName('StudentEntryRow')
class StudentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();

  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get fatherName => text().withDefault(const Constant(''))();
  TextColumn get studentClass => text().withDefault(const Constant(''))();
  TextColumn get division => text().withDefault(const Constant(''))();

  /// School register number. Text, not an integer - real registers use values
  /// like `12/A` and `0034` where a dropped leading zero changes the meaning.
  TextColumn get rollNumber => text().withDefault(const Constant(''))();

  TextColumn get bloodGroup => text().withDefault(const Constant(''))();
  DateTimeColumn get dob => dateTime().nullable()();
  TextColumn get mobile => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();

  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get remotePhotoUrl => text().nullable()();

  /// Stores the `SyncStatus` enum name. Kept as text rather than an int so a
  /// database dump is readable during a support call.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))();
  TextColumn get syncError => text().nullable()();

  /// When the worker last *attempted* to upload this row.
  ///
  /// Deliberately separate from [updatedAt], which is when the operator last
  /// edited the record. The retry backoff and the stuck-upload sweep both need
  /// "when did we last try", and reading the edit time instead made both
  /// meaningless: a row edited an hour ago was always already past its backoff
  /// window, and was always old enough to look stuck the instant it started
  /// uploading.
  ///
  /// Null until the first attempt. Device-local bookkeeping - never uploaded.
  DateTimeColumn get lastSyncAttemptAt => dateTime().nullable()();

  /// When this row's DETAILS last landed in Firestore.
  ///
  /// Distinct from [syncStatus] because a row can be `failed` while the office
  /// already holds the student record: an upload writes the document first and
  /// the photo separately, so a missing Storage bucket fails the photo and
  /// nothing else. Without this marker the app could only say "upload failed",
  /// which is alarming and wrong - the submission is safely on the server and
  /// only the picture is outstanding.
  ///
  /// Null until the first successful document write. Device-local, never
  /// uploaded.
  DateTimeColumn get detailsSyncedAt => dateTime().nullable()();

  /// Stores the `ApprovalStatus` enum name - the admin's review decision,
  /// independent of whether the row has uploaded yet.
  TextColumn get approvalStatus => text().withDefault(const Constant('pending'))();

  /// Why an admin rejected it. Null unless approvalStatus == 'rejected'.
  TextColumn get rejectionReason => text().nullable()();

  /// Auth UID of the admin who approved or rejected, and when. Kept as an
  /// audit trail - "who let this print?" is the first question asked when a
  /// wrong card reaches a school.
  TextColumn get reviewedBy => text().nullable()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('SchoolConfigRow')
class SchoolConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get addressLine => text().withDefault(const Constant(''))();
  TextColumn get contactLine => text().withDefault(const Constant(''))();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get localLogoPath => text().nullable()();
  TextColumn get principalSignatureUrl => text().nullable()();
  TextColumn get localPrincipalSignaturePath => text().nullable()();

  TextColumn get cardSizeId => text().withDefault(const Constant('v54x86'))();
  TextColumn get templateId => text().withDefault(const Constant('default_vertical'))();

  /// Comma-separated `StudentField.key` values. A join table would be more
  /// normalised but this set is tiny, always read whole, and never queried by
  /// member - the simpler shape wins.
  TextColumn get enabledFields => text().withDefault(const Constant(''))();

  IntColumn get primaryColor => integer().withDefault(const Constant(0xFFD32F2F))();
  IntColumn get secondaryColor => integer().withDefault(const Constant(0xFF1565C0))();
  IntColumn get headerColor => integer().withDefault(const Constant(0xFF1565C0))();
  IntColumn get photoBackground => integer().withDefault(const Constant(0xFFFFFFFF))();

  /// JSON object of division -> ARGB int, e.g. `{"A":4294901760}`.
  ///
  /// JSON rather than the comma-joined shape used by [enabledFields] because
  /// this is key/value rather than a flat set, and a hand-edited value with a
  /// stray delimiter would silently mis-colour cards.
  TextColumn get divisionColors => text().withDefault(const Constant('{}'))();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Immutable audit trail. Every meaningful admin action (approve, reject,
/// export, print) is recorded here so "who did what and when?" has an answer.
@DataClassName('AuditLogRow')
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Machine-readable verb: 'approve', 'reject', 'export_csv',
  /// 'print_batch', 'create_school', 'update_school', 'sync_pass'.
  TextColumn get action => text()();

  /// What kind of entity was affected: 'student', 'school', 'print_batch'.
  TextColumn get entityType => text()();

  /// The id of the affected entity (student id, school id, batch id).
  TextColumn get entityId => text()();

  /// Auth UID of the admin who performed the action.
  TextColumn get actorUid => text()();

  /// Free-form JSON blob with extra context. Kept as text so the table stays
  /// flat and a new detail field never requires a migration.
  TextColumn get details => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
}

/// One print run. Ties a point-in-time snapshot of "N cards on M sheets" to
/// the admin who pressed "Generate" and the school it was for, so an audit
/// trail exists for every batch of cards that reaches a cutter.
@DataClassName('PrintBatchRow')
class PrintBatches extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  IntColumn get cardCount => integer()();

  /// '12x18', 'a4', or 'single'.
  TextColumn get sheetType => text()();
  IntColumn get sheetCount => integer()();

  /// Auth UID of the admin who triggered the print run.
  TextColumn get generatedBy => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: <Type>[StudentEntries, SchoolConfigs, AuditLogs, PrintBatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test constructor - lets the suite pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 -> v2: per-division accent colours. Additive with a default, so
          // existing rows keep working and every card stays on the school
          // colour until an admin sets division colours.
          if (from < 2) {
            // Cast because `addColumn` wants GeneratedColumn<Object> while the
            // generated accessor is the narrower GeneratedColumn<String>.
            await m.addColumn(
              schoolConfigs,
              schoolConfigs.divisionColors as GeneratedColumn<Object>,
            );
          }

          // v2 -> v3: the admin approval workflow. All four columns are
          // additive with safe defaults, so entries captured before this
          // release land in the review queue rather than silently counting as
          // approved - the conservative direction for something that gates
          // printing.
          if (from < 3) {
            await m.addColumn(
              studentEntries,
              studentEntries.approvalStatus as GeneratedColumn<Object>,
            );
            await m.addColumn(
              studentEntries,
              studentEntries.rejectionReason as GeneratedColumn<Object>,
            );
            await m.addColumn(
              studentEntries,
              studentEntries.reviewedBy as GeneratedColumn<Object>,
            );
            await m.addColumn(
              studentEntries,
              studentEntries.reviewedAt as GeneratedColumn<Object>,
            );
          }

          // v3 -> v4: principal signature storage.
          if (from < 4) {
            await m.addColumn(
              schoolConfigs,
              schoolConfigs.principalSignatureUrl as GeneratedColumn<Object>,
            );
            await m.addColumn(
              schoolConfigs,
              schoolConfigs.localPrincipalSignaturePath as GeneratedColumn<Object>,
            );
          }

          // v4 -> v5: audit trail and print batch tracking.
          if (from < 5) {
            await m.createTable(auditLogs);
            await m.createTable(printBatches);
          }

          // v5 -> v6: roll number.
          //
          // The column is additive with an empty default, but the field also
          // has to be switched ON for schools that already exist - the enabled
          // field set is stored per school, so without this backfill a roll
          // number column would exist that no form ever renders. New schools
          // pick it up automatically via `SchoolConfig.allFieldKeys`.
          if (from < 6) {
            await m.addColumn(
              studentEntries,
              studentEntries.rollNumber as GeneratedColumn<Object>,
            );
            await customStatement('''
UPDATE school_configs
   SET enabled_fields = CASE
         WHEN enabled_fields IS NULL OR enabled_fields = ''
           THEN 'rollNumber'
         ELSE enabled_fields || ',rollNumber'
       END
 WHERE enabled_fields IS NULL
    OR enabled_fields NOT LIKE '%rollNumber%'
''');
          }

          // v6 -> v7: give sync its own clock.
          //
          // Nullable with no backfill on purpose. A null reads as "never
          // attempted", which makes every existing row immediately eligible
          // for one upload attempt - the correct behaviour after an upgrade,
          // and it cannot strand a row that was mid-retry.
          if (from < 7) {
            await m.addColumn(
              studentEntries,
              studentEntries.lastSyncAttemptAt as GeneratedColumn<Object>,
            );
          }

          // v7 -> v8: remember that the details reached the server, separately
          // from whether the whole row succeeded.
          //
          // Backfilled for rows already synced: those demonstrably reached
          // Firestore, and leaving them null would make a settled submission
          // look like it had never uploaded.
          if (from < 8) {
            await m.addColumn(
              studentEntries,
              studentEntries.detailsSyncedAt as GeneratedColumn<Object>,
            );
            await customStatement(
              'UPDATE student_entries '
              'SET details_synced_at = updated_at '
              "WHERE sync_status = 'synced'",
            );
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // Foreign keys are off by default in SQLite and must be re-enabled
          // on every connection, not just at creation time.
          await customStatement('PRAGMA foreign_keys = ON');

          // A record left as 'syncing' means the process died mid-upload.
          // Reset it so the worker retries instead of it being stranded.
          await (update(studentEntries)
                ..where((StudentEntries t) => t.syncStatus.equals('syncing')))
              .write(const StudentEntriesCompanion(syncStatus: Value<String>('pending')));
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'id_card_db');
}
