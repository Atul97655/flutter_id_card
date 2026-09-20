import 'package:drift/drift.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';

/// Small named values that belong to the device rather than to any record.
///
/// Currently one: the watermark behind the notification badge. See
/// [notificationsSeenAtKey].
class AppFlagRepository {
  AppFlagRepository(this._db);

  final AppDatabase _db;

  /// When the operator last opened the notifications screen.
  ///
  /// The badge counts notifications newer than this. It has to be persisted
  /// rather than held in memory: the feed is rebuilt from live state on every
  /// launch, so an in-memory "seen" flag would reset the badge to the full
  /// count every time the app started - which is exactly the complaint this
  /// exists to answer.
  static const String notificationsSeenAtKey = 'notificationsSeenAt';

  /// Whether this installation prints cards, mirrored down from the panel's
  /// `config/panel` document.
  ///
  /// Cached locally rather than read live for the same reason school settings
  /// are: the app has to work on a school's dead connection, and a feature
  /// that disappears when the signal drops is worse than one that is simply
  /// on or off. Absent until the first sync, which reads as off - matching
  /// the panel's own default.
  static const String printingEnabledKey = 'printingEnabled';

  Stream<DateTime?> watchDateTime(String key) {
    return (_db.select(
      _db.appFlags,
    )..where((AppFlags t) => t.key.equals(key))).watchSingleOrNull().map(
      (AppFlagRow? row) => row == null ? null : DateTime.tryParse(row.value),
    );
  }

  Future<DateTime?> readDateTime(String key) async {
    final AppFlagRow? row = await (_db.select(
      _db.appFlags,
    )..where((AppFlags t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value);
  }

  /// Stored as an ISO-8601 UTC string rather than a Drift `dateTime` column so
  /// this one table can hold any kind of flag without a migration per type.
  Future<void> writeDateTime(String key, DateTime value) {
    return _db
        .into(_db.appFlags)
        .insertOnConflictUpdate(
          AppFlagsCompanion(
            key: Value<String>(key),
            value: Value<String>(value.toUtc().toIso8601String()),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  Stream<bool> watchBool(String key, {bool orElse = false}) {
    return (_db.select(_db.appFlags)..where((AppFlags t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((AppFlagRow? row) => row == null ? orElse : row.value == 'true');
  }

  Future<void> writeBool(String key, bool value) {
    return _db
        .into(_db.appFlags)
        .insertOnConflictUpdate(
          AppFlagsCompanion(
            key: Value<String>(key),
            value: Value<String>(value ? 'true' : 'false'),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  /// Marks everything currently in the feed as seen.
  Future<void> markNotificationsSeen() =>
      writeDateTime(notificationsSeenAtKey, DateTime.now());
}
