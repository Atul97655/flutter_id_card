import 'package:drift/native.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sync bookkeeping: the retry backoff and the stuck-upload sweep.
///
/// Both used to measure `updatedAt` - when the OPERATOR last edited the row -
/// while meaning "when did the worker last try". That made the backoff a no-op
/// (an edit is almost always older than any backoff window) and made the sweep
/// fire on uploads that had only just started. `lastSyncAttemptAt` separates
/// the two clocks; these tests pin that apart.
void main() {
  late AppDatabase db;
  late StudentRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StudentRepository(db);
  });

  tearDown(() async => db.close());

  group('Schema v7', () {
    test('declares version 7', () {
      expect(db.schemaVersion, 7);
    });

    test('a fresh entry has never been attempted', () async {
      await repo.save(_entry());
      final StudentEntry saved = (await repo.findById('e1'))!;
      expect(saved.lastSyncAttemptAt, isNull);
    });
  });

  group('The attempt clock is separate from the edit clock', () {
    test('markSyncing stamps it without touching updatedAt', () async {
      final DateTime edited = DateTime(2026, 1, 1);
      await repo.save(_entry(updatedAt: edited));

      await repo.markSyncing('e1');
      final StudentEntry after = (await repo.findById('e1'))!;

      expect(after.syncStatus, SyncStatus.syncing);
      expect(after.updatedAt, edited, reason: 'syncing is not an edit');
      expect(after.lastSyncAttemptAt, isNotNull);
      expect(
        after.lastSyncAttemptAt!.isAfter(edited),
        isTrue,
        reason: 'the attempt happened now, not when the row was typed',
      );
    });

    test('markFailed stamps it and counts the attempt', () async {
      final DateTime edited = DateTime(2026, 1, 1);
      await repo.save(_entry(updatedAt: edited));

      await repo.markFailed('e1', 'server unreachable', 0);
      final StudentEntry after = (await repo.findById('e1'))!;

      expect(after.syncStatus, SyncStatus.failed);
      expect(after.syncAttempts, 1);
      expect(after.syncError, 'server unreachable');
      expect(after.updatedAt, edited);
      expect(after.lastSyncAttemptAt, isNotNull);
    });

    test('markSynced does not disturb the edit clock', () async {
      final DateTime edited = DateTime(2026, 1, 1);
      await repo.save(_entry(updatedAt: edited));

      await repo.markSynced('e1', remotePhotoUrl: 'https://example/p.png');
      final StudentEntry after = (await repo.findById('e1'))!;

      expect(after.syncStatus, SyncStatus.synced);
      expect(after.syncError, isNull);
      expect(after.updatedAt, edited);
    });

    test('an explicit retry clears the clock so it goes at once', () async {
      await repo.save(_entry());
      await repo.markFailed('e1', 'boom', 3);
      expect((await repo.findById('e1'))!.lastSyncAttemptAt, isNotNull);

      await repo.resetFailures('school-1');
      final StudentEntry after = (await repo.findById('e1'))!;

      expect(after.syncStatus, SyncStatus.pending);
      expect(after.syncAttempts, 0);
      expect(
        after.lastSyncAttemptAt,
        isNull,
        reason: 'the operator just reacted - do not make them wait out a '
            'backoff from the failure they are retrying',
      );
    });
  });

  group('resetStaleSyncing', () {
    test('leaves an upload that has only just started alone', () async {
      // The regression: this row was edited long ago but started uploading a
      // moment ago. Measuring the edit time made it look stuck immediately,
      // so a live upload got reset and sent twice.
      await repo.save(_entry(updatedAt: DateTime(2026, 1, 1)));
      await repo.markSyncing('e1');

      final int reset = await repo.resetStaleSyncing();

      expect(reset, 0);
      expect((await repo.findById('e1'))!.syncStatus, SyncStatus.syncing);
    });

    test('resets an upload that really has been in flight too long', () async {
      await repo.save(_entry());
      await repo.markSyncing('e1');

      // Push the attempt clock back past the window.
      await db.customStatement(
        'UPDATE student_entries SET last_sync_attempt_at = ? WHERE id = ?',
        <Object>[
          DateTime.now()
                  .subtract(const Duration(minutes: 30))
                  .millisecondsSinceEpoch ~/
              1000,
          'e1',
        ],
      );

      final int reset = await repo.resetStaleSyncing();

      expect(reset, 1);
      expect((await repo.findById('e1'))!.syncStatus, SyncStatus.pending);
    });

    test('treats a row with no attempt clock as stuck', () async {
      // Only reachable from a build predating the column.
      await repo.save(_entry());
      await db.customStatement(
        '''
UPDATE student_entries
   SET sync_status = 'syncing', last_sync_attempt_at = NULL
 WHERE id = ?
''',
        <Object>['e1'],
      );

      expect(await repo.resetStaleSyncing(), 1);
      expect((await repo.findById('e1'))!.syncStatus, SyncStatus.pending);
    });

    test('ignores rows that are not syncing', () async {
      await repo.save(_entry());
      await repo.markFailed('e1', 'boom', 0);
      expect(await repo.resetStaleSyncing(), 0);
    });
  });

  group('Backoff arithmetic', () {
    // Mirrors SyncService._shouldDelay. Kept here rather than reaching into a
    // private method: the rule is what matters, and it is the rule that was
    // silently dead.
    bool shouldDelay(StudentEntry e, {required DateTime now}) {
      if (e.syncAttempts == 0) return false;
      final DateTime? last = e.lastSyncAttemptAt;
      if (last == null) return false;
      final int seconds = <int>[300, 1 << e.syncAttempts].reduce(
        (int a, int b) => a < b ? a : b,
      );
      return now.isBefore(last.add(Duration(seconds: seconds)));
    }

    final DateTime now = DateTime(2026, 9, 10, 12);

    test('a never-attempted row goes immediately', () {
      expect(
        shouldDelay(_entry(attempts: 0, lastAttempt: null), now: now),
        isFalse,
      );
    });

    test('a row that just failed waits', () {
      expect(
        shouldDelay(
          _entry(attempts: 3, lastAttempt: now.subtract(const Duration(seconds: 2))),
          now: now,
        ),
        isTrue,
        reason: '3 attempts means an 8 second window; 2 seconds have passed',
      );
    });

    test('a row whose window has elapsed goes', () {
      expect(
        shouldDelay(
          _entry(attempts: 3, lastAttempt: now.subtract(const Duration(seconds: 30))),
          now: now,
        ),
        isFalse,
      );
    });

    test('the wait is capped at five minutes', () {
      expect(
        shouldDelay(
          _entry(attempts: 20, lastAttempt: now.subtract(const Duration(minutes: 6))),
          now: now,
        ),
        isFalse,
        reason: '2^20 seconds is 12 days without the cap',
      );
    });

    test('the old behaviour would have skipped the wait entirely', () {
      // What the code used to do: measure from the edit time. An entry edited
      // an hour ago and failed one second ago was treated as ready.
      final StudentEntry e = _entry(
        attempts: 3,
        lastAttempt: now.subtract(const Duration(seconds: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      );

      final bool oldRule = now.isBefore(
        e.updatedAt.add(const Duration(seconds: 8)),
      );
      expect(oldRule, isFalse, reason: 'this is the bug: no delay applied');
      expect(shouldDelay(e, now: now), isTrue, reason: 'the fix delays it');
    });
  });
}

StudentEntry _entry({
  String id = 'e1',
  int attempts = 0,
  DateTime? lastAttempt,
  DateTime? updatedAt,
}) {
  final DateTime stamp = updatedAt ?? DateTime(2026, 9, 10);
  return StudentEntry(
    id: id,
    schoolId: 'school-1',
    name: 'TEST STUDENT',
    syncAttempts: attempts,
    lastSyncAttemptAt: lastAttempt,
    createdAt: stamp,
    updatedAt: stamp,
  );
}
