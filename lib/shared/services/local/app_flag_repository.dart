import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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

  /// Which notifications the operator has already looked at, by id.
  ///
  /// This replaced a bare timestamp as the thing the badge is counted
  /// against, because a timestamp could not answer the question honestly.
  /// The watermark was stamped with the device clock while the feed's own
  /// times come off the server, so a phone running a few minutes slow -
  /// ordinary on a hand-set clock - produced notifications dated *after* the
  /// moment they were read, and the badge came straight back on the next
  /// launch. No amount of looking could clear it.
  ///
  /// Ids are exact and have no clock in them. The set written is the set that
  /// was on screen, replacing whatever was there, so it stays the size of the
  /// feed instead of growing forever, and anything that has since dropped out
  /// of the feed drops out of here with it.
  static const String notificationsSeenIdsKey = 'notificationsSeenIds';

  /// Which returned cards the operator has dismissed the Profile banner for.
  ///
  /// Separate from the feed because it answers a different question. The feed
  /// asks "have you read this"; the banner asks "do you still want shouting
  /// at about it". A card that comes back *after* a dismissal is not in this
  /// set, so the banner returns for it and only for it.
  static const String returnedDismissedIdsKey = 'returnedDismissedIds';

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

  // ------------------------------------------------------------------
  // String sets
  // ------------------------------------------------------------------

  /// Stored as a JSON array in the same text column every other flag uses, so
  /// a new kind of flag never costs a schema migration.
  ///
  /// A malformed or legacy value reads as empty rather than throwing. The one
  /// thing this must never do is crash the notification feed on launch
  /// because a row it did not write is sitting in the table.
  static Set<String> _decodeSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is! List<Object?>) return <String>{};
      return parsed.whereType<String>().toSet();
    } on FormatException {
      return <String>{};
    }
  }

  /// The decoder, for the test that pins its behaviour on junk input.
  ///
  /// Exposed deliberately. This runs on every launch inside the notification
  /// feed, and "does not throw on a row it did not write" is a promise worth
  /// being able to check directly rather than inferring from a screen.
  @visibleForTesting
  static Set<String> decodeSetForTest(String? raw) => _decodeSet(raw);

  Stream<Set<String>> watchStringSet(String key) {
    return (_db.select(_db.appFlags)..where((AppFlags t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((AppFlagRow? row) => _decodeSet(row?.value));
  }

  Future<Set<String>> readStringSet(String key) async {
    final AppFlagRow? row = await (_db.select(
      _db.appFlags,
    )..where((AppFlags t) => t.key.equals(key))).getSingleOrNull();
    return _decodeSet(row?.value);
  }

  /// Replaces the stored set. Sorted so the same set always serialises to the
  /// same string - otherwise every write would look like a change to Drift's
  /// stream and rebuild the feed for nothing.
  Future<void> writeStringSet(String key, Set<String> value) {
    final List<String> sorted = value.toList()..sort();
    return _db
        .into(_db.appFlags)
        .insertOnConflictUpdate(
          AppFlagsCompanion(
            key: Value<String>(key),
            value: Value<String>(jsonEncode(sorted)),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  /// Adds to the stored set, keeping what is already there.
  Future<Set<String>> addToStringSet(String key, Set<String> value) async {
    final Set<String> merged = (await readStringSet(key))..addAll(value);
    await writeStringSet(key, merged);
    return merged;
  }

  /// Marks exactly the notifications that were on screen as seen.
  ///
  /// Takes the ids rather than stamping the clock. See
  /// [notificationsSeenIdsKey] for why the clock was the wrong instrument.
  Future<void> markNotificationsSeen(Set<String> visibleIds) async {
    await writeStringSet(notificationsSeenIdsKey, visibleIds);
    // The timestamp is still written. Nothing reads it for the badge any
    // more, but it is a cheap record of when the screen was last opened and
    // removing the column would be a migration for no gain.
    await writeDateTime(notificationsSeenAtKey, DateTime.now());
  }
}
