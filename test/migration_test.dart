/// Migrations, run against a populated database.
///
/// A migration that loses data does not throw. It returns fewer rows, or a
/// column full of nulls, and everything downstream keeps working - which is
/// why this is the one test in the suite worth writing before the code it
/// tests. The assertions below are deliberately about *values surviving*,
/// not about the schema being shaped correctly; a schema assertion passes on
/// an empty table.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'schema_version.dart';
import 'support/legacy_schema.dart';

/// A v9 database holding the kinds of row a real phone would have.
///
/// Every one of these is a state the app can genuinely be in, and several of
/// them are states that have caused bugs before: a row parked after eight
/// failed photo uploads, a row whose photo exists only on the server, a
/// rejected row carrying a reason the teacher still needs to read.
raw.Database seededV9() {
  final raw.Database db = openLegacyDatabase(version: 9, statements: kSchemaV9);

  final DateTime created = DateTime.utc(2026, 3, 1, 9, 30);
  final DateTime updated = DateTime.utc(2026, 3, 2, 14, 15);
  final DateTime dob = DateTime.utc(2015, 12, 7);

  void entry({
    required String id,
    required String name,
    required String status,
    required String approval,
    int attempts = 0,
    String? localPhoto,
    String? thumb,
    String? rejection,
    bool detailsSynced = false,
  }) {
    db.execute(
      'INSERT INTO student_entries ('
      '"id","school_id","name","father_name","student_class","division",'
      '"roll_number","blood_group","dob","mobile","address",'
      '"local_photo_path","remote_photo_url","photo_thumb","sync_status",'
      '"sync_attempts","sync_error","last_sync_attempt_at",'
      '"details_synced_at","approval_status","rejection_reason",'
      '"reviewed_by","reviewed_at","created_at","updated_at") '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      <Object?>[
        id,
        'SJS-2026-0041',
        name,
        'RAMESH KUMAR',
        '5TH',
        'B',
        '024',
        'O+',
        secs(dob),
        '9035252327',
        'SANTOSH NAGAR, NEKAR NAGAR, OLD HUBLI - 580024',
        localPhoto,
        null,
        thumb,
        status,
        attempts,
        attempts > 0 ? 'upload failed' : null,
        attempts > 0 ? secs(updated) : null,
        detailsSynced ? secs(updated) : null,
        approval,
        rejection,
        approval == 'pending' ? null : 'admin-uid',
        approval == 'pending' ? null : secs(updated),
        secs(created),
        secs(updated),
      ],
    );
  }

  entry(
    id: 'e-synced',
    name: 'ADITYA KUMAR',
    status: 'synced',
    approval: 'approved',
    localPhoto: '/data/photos/e-synced.png',
    thumb: 'AAAA',
    detailsSynced: true,
  );
  // The row that has caused real trouble: photo upload gave up after eight
  // attempts, so it is invisible to the upload queue.
  entry(
    id: 'e-parked',
    name: 'SNEHA PATIL',
    status: 'failed',
    approval: 'pending',
    attempts: 8,
    localPhoto: '/data/photos/e-parked.png',
  );
  // Arrived from the server; this device never held the photo file.
  entry(
    id: 'e-remote-only',
    name: 'ROHAN DESAI',
    status: 'synced',
    approval: 'printed',
    thumb: 'BBBB',
    detailsSynced: true,
  );
  entry(
    id: 'e-rejected',
    name: 'ARJUN NAIK',
    status: 'synced',
    approval: 'rejected',
    rejection: 'PHOTO NOT CLEAR, RESUBMIT',
    localPhoto: '/data/photos/e-rejected.png',
    detailsSynced: true,
  );

  db.execute(
    'INSERT INTO school_configs ('
    '"id","name","address_line","contact_line","card_size_id","template_id",'
    '"enabled_fields","primary_color","secondary_color","header_color",'
    '"photo_background","division_colors","updated_at") '
    'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
    <Object?>[
      'SJS-2026-0041',
      'ST. JOHN SAMARITAN ENGLISH MEDIUM SCHOOL',
      'Gurusiddeshwar Colony, Nekar Nagar, Old Hubli - 580024',
      'Ph: 0836-2008532',
      'v54x86',
      'default_vertical',
      'name,fatherName,studentClass,division,rollNumber,dob,mobile,address',
      4292030255,
      4279592384,
      4279592384,
      4294967295,
      '{"A":4282339765}',
      secs(updated),
    ],
  );

  db.execute(
    'INSERT INTO app_flags ("key","value","updated_at") VALUES (?,?,?)',
    <Object?>['printingEnabled', 'false', secs(updated)],
  );

  db.execute(
    'INSERT INTO audit_logs ('
    '"action","entity_type","entity_id","actor_uid","details","created_at") '
    'VALUES (?,?,?,?,?,?)',
    <Object?>[
      'approve',
      'entry',
      'e-synced',
      'admin-uid',
      'approved in bulk',
      secs(updated),
    ],
  );

  return db;
}

void main() {
  test('the frozen v9 fixture really is at version 9', () {
    final raw.Database db = seededV9();
    addTearDown(db.close);

    expect(db.select('PRAGMA user_version').first['user_version'], 9);
  });

  test('upgrading a populated v9 database keeps every student row', () async {
    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seededV9()),
    );
    addTearDown(db.close);

    final List<StudentEntryRow> rows = await db.select(db.studentEntries).get();

    expect(
      rows.map((StudentEntryRow r) => r.id).toSet(),
      <String>{'e-synced', 'e-parked', 'e-remote-only', 'e-rejected'},
      reason:
          'a migration that drops rows is silent - this is the assertion '
          'that makes it loud',
    );
  });

  test('every field on a migrated row survives with its value', () async {
    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seededV9()),
    );
    addTearDown(db.close);

    final StudentEntryRow row = await (db.select(
      db.studentEntries,
    )..where(($StudentEntriesTable t) => t.id.equals('e-synced'))).getSingle();

    expect(row.name, 'ADITYA KUMAR');
    expect(row.fatherName, 'RAMESH KUMAR');
    expect(row.studentClass, '5TH');
    expect(row.division, 'B');
    expect(row.rollNumber, '024', reason: 'leading zero must not be eaten');
    expect(row.bloodGroup, 'O+');
    expect(row.mobile, '9035252327');
    expect(row.address, 'SANTOSH NAGAR, NEKAR NAGAR, OLD HUBLI - 580024');
    // Drift hands back a LOCAL DateTime, so these compare instants rather
    // than wall-clock fields. On a machine at IST the naive comparison is
    // off by 5h30m, which would have read as "the migration corrupted the
    // date" when nothing of the sort happened.
    expect(row.dob?.toUtc(), DateTime.utc(2015, 12, 7));
    expect(row.localPhotoPath, '/data/photos/e-synced.png');
    expect(row.photoThumb, 'AAAA');
    expect(row.syncStatus, SyncStatus.synced.name);
    expect(row.approvalStatus, ApprovalStatus.approved.name);
    expect(row.detailsSyncedAt, isNotNull);
    expect(row.createdAt.toUtc(), DateTime.utc(2026, 3, 1, 9, 30));
    expect(row.updatedAt.toUtc(), DateTime.utc(2026, 3, 2, 14, 15));
  });

  test('a parked row keeps its attempt count and stays parked', () async {
    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seededV9()),
    );
    addTearDown(db.close);

    final StudentEntryRow row = await (db.select(
      db.studentEntries,
    )..where(($StudentEntriesTable t) => t.id.equals('e-parked'))).getSingle();

    expect(row.syncAttempts, 8);
    expect(row.localPhotoPath, isNotNull);
    expect(row.photoThumb, anyOf(isNull, isEmpty));
    expect(
      row.syncError,
      isNotNull,
      reason:
          'the reason it is parked has to survive, or nobody can '
          'diagnose it afterwards',
    );
  });

  test('a rejected row keeps the reason the teacher has to read', () async {
    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seededV9()),
    );
    addTearDown(db.close);

    final StudentEntryRow row =
        await (db.select(db.studentEntries)
              ..where(($StudentEntriesTable t) => t.id.equals('e-rejected')))
            .getSingle();

    expect(row.approvalStatus, ApprovalStatus.rejected.name);
    expect(row.rejectionReason, 'PHOTO NOT CLEAR, RESUBMIT');
    expect(row.reviewedBy, 'admin-uid');
    expect(row.reviewedAt, isNotNull);
  });

  test('school config, flags and audit rows survive too', () async {
    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seededV9()),
    );
    addTearDown(db.close);

    final SchoolConfigRow school = await db
        .select(db.schoolConfigs)
        .getSingle();
    expect(school.name, 'ST. JOHN SAMARITAN ENGLISH MEDIUM SCHOOL');
    expect(school.enabledFields, contains('rollNumber'));
    expect(
      school.divisionColors,
      '{"A":4282339765}',
      reason:
          'per-division colours are card artwork - losing them changes '
          'what prints',
    );

    final AppFlagRow flag = await db.select(db.appFlags).getSingle();
    expect(flag.key, 'printingEnabled');
    expect(flag.value, 'false');

    final AuditLogRow audit = await db.select(db.auditLogs).getSingle();
    expect(audit.action, 'approve');
    expect(audit.entityId, 'e-synced');
  });

  test('the migrated database lands on the current schema version', () async {
    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seededV9()),
    );
    addTearDown(db.close);

    final List<QueryRow> rows = await db
        .customSelect('PRAGMA user_version')
        .get();

    expect(rows.first.read<int>('user_version'), kExpectedSchemaVersion);
    expect(db.schemaVersion, kExpectedSchemaVersion);
  });

  group('v8 -> v9, the last migration that actually moved schema', () {
    /// A v8 database with one student in it.
    ///
    /// Deliberately one version further back than the fixture above: this is
    /// the only case in this file where `onUpgrade` really runs, so it is the
    /// only one that proves the harness can observe a migration at all.
    raw.Database seededV8() {
      final raw.Database db = openLegacyDatabase(
        version: 8,
        statements: kSchemaV8,
      );
      db.execute(
        'INSERT INTO student_entries ('
        '"id","school_id","name","father_name","student_class","division",'
        '"roll_number","blood_group","mobile","address","sync_status",'
        '"sync_attempts","approval_status","created_at","updated_at") '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        <Object?>[
          'e-v8',
          'SJS-2026-0041',
          'MEERA JOSHI',
          'SANJAY JOSHI',
          '1ST',
          'C',
          '031',
          'B+',
          '9448782053',
          'OLD HUBLI',
          'synced',
          0,
          'approved',
          secs(DateTime.utc(2026, 2, 1)),
          secs(DateTime.utc(2026, 2, 2)),
        ],
      );
      return db;
    }

    test('the v8 fixture is genuinely missing what v9 added', () {
      final raw.Database db = seededV8();
      addTearDown(db.close);

      final String ddl =
          db
                  .select(
                    "SELECT sql FROM sqlite_master WHERE name = 'student_entries'",
                  )
                  .first['sql']
              as String;

      expect(ddl, isNot(contains('photo_thumb')));
      expect(
        db.select("SELECT name FROM sqlite_master WHERE name = 'app_flags'"),
        isEmpty,
      );
    });

    test('the student survives the upgrade intact', () async {
      final AppDatabase db = AppDatabase.forTesting(
        NativeDatabase.opened(seededV8()),
      );
      addTearDown(db.close);

      final StudentEntryRow row = await db
          .select(db.studentEntries)
          .getSingle();

      expect(row.id, 'e-v8');
      expect(row.name, 'MEERA JOSHI');
      expect(row.rollNumber, '031');
      expect(row.approvalStatus, ApprovalStatus.approved.name);
      expect(
        row.photoThumb,
        isNull,
        reason:
            'v9 adds the column with no backfill - a row from v8 has no '
            'thumbnail on the server either, so inventing one would be a lie',
      );
    });

    test('the flags table arrives and is usable', () async {
      final AppDatabase db = AppDatabase.forTesting(
        NativeDatabase.opened(seededV8()),
      );
      addTearDown(db.close);

      await db
          .into(db.appFlags)
          .insert(
            AppFlagsCompanion.insert(
              key: 'printingEnabled',
              value: 'false',
              updatedAt: DateTime.utc(2026, 3, 2),
            ),
          );

      expect((await db.select(db.appFlags).get()).single.value, 'false');
    });
  });

  group('v7 -> v9, the one migration that transforms data', () {
    /// v7, holding one synced row and one that never left the device.
    ///
    /// 7 -> 8 stamps `details_synced_at` from `updated_at`, but only
    /// `WHERE sync_status = 'synced'`. A backfill with a condition on it is
    /// the kind that fails quietly: widen the condition by accident and every
    /// unsent row starts claiming it reached the server, which is exactly the
    /// lie the sync worker would then believe.
    raw.Database seededV7() {
      final raw.Database db = openLegacyDatabase(
        version: 7,
        statements: kSchemaV7,
      );
      void row(String id, String name, String status) {
        db.execute(
          'INSERT INTO student_entries ('
          '"id","school_id","name","sync_status","sync_attempts",'
          '"approval_status","created_at","updated_at") '
          'VALUES (?,?,?,?,?,?,?,?)',
          <Object?>[
            id,
            'SJS-2026-0041',
            name,
            status,
            0,
            'pending',
            secs(DateTime.utc(2026, 2, 1)),
            secs(DateTime.utc(2026, 2, 2)),
          ],
        );
      }

      row('e-v7-synced', 'MEERA JOSHI', 'synced');
      row('e-v7-pending', 'KAVYA HEGDE', 'pending');
      row('e-v7-failed', 'ARJUN NAIK', 'failed');
      return db;
    }

    test('the v7 fixture is genuinely missing the column', () {
      final raw.Database db = seededV7();
      addTearDown(db.close);

      final String ddl =
          db
                  .select(
                    "SELECT sql FROM sqlite_master WHERE name = 'student_entries'",
                  )
                  .first['sql']
              as String;

      expect(ddl, isNot(contains('details_synced_at')));
    });

    test('only rows that had actually synced are stamped', () async {
      final AppDatabase db = AppDatabase.forTesting(
        NativeDatabase.opened(seededV7()),
      );
      addTearDown(db.close);

      final Map<String, StudentEntryRow> byId = <String, StudentEntryRow>{
        for (final StudentEntryRow r
            in await db.select(db.studentEntries).get())
          r.id: r,
      };

      expect(
        byId['e-v7-synced']!.detailsSyncedAt?.toUtc(),
        DateTime.utc(2026, 2, 2),
        reason: 'a settled submission must not look like it never uploaded',
      );
      expect(
        byId['e-v7-pending']!.detailsSyncedAt,
        isNull,
        reason:
            'a row that never reached the server must not be stamped as '
            'though it had',
      );
      expect(byId['e-v7-failed']!.detailsSyncedAt, isNull);
    });

    test('all three rows are still there afterwards', () async {
      final AppDatabase db = AppDatabase.forTesting(
        NativeDatabase.opened(seededV7()),
      );
      addTearDown(db.close);

      expect((await db.select(db.studentEntries).get()).length, 3);
    });
  });

  test('a row left mid-upload is reset so the worker retries it', () async {
    final raw.Database seeded = seededV9();
    seeded.execute(
      "UPDATE student_entries SET sync_status = 'syncing' WHERE id = ?",
      <Object?>['e-parked'],
    );

    final AppDatabase db = AppDatabase.forTesting(
      NativeDatabase.opened(seeded),
    );
    addTearDown(db.close);

    final StudentEntryRow row = await (db.select(
      db.studentEntries,
    )..where(($StudentEntriesTable t) => t.id.equals('e-parked'))).getSingle();

    expect(
      row.syncStatus,
      SyncStatus.pending.name,
      reason:
          'beforeOpen exists to rescue rows stranded by a process that '
          'died mid-upload',
    );
  });
}
