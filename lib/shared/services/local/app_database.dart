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

@DriftDatabase(tables: <Type>[StudentEntries, SchoolConfigs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test constructor - lets the suite pass an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

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
