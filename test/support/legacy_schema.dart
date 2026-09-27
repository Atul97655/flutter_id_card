/// Databases at old schema versions, built by hand, so migrations can be
/// tested against something that looks like a phone in the field.
///
/// Why this exists
/// ---------------
/// Every migration in `AppDatabase` so far has been additive, and every one
/// of them was shipped without a test that ran it against populated data.
/// That worked, but it worked by luck: an additive migration that drops rows
/// does not throw. It returns an empty table, and the first person to notice
/// is a teacher who says last term's cards are gone.
///
/// A migration test needs a database that is genuinely at the old version -
/// not the current schema with a lower number written on it. So the DDL below
/// is the literal `sqlite_master` dump of v9, taken while v9 was still the
/// live schema. It is frozen on purpose: if someone edits a table definition
/// in `app_database.dart`, this copy must NOT follow, or the test stops
/// testing anything.
library;

import 'package:sqlite3/sqlite3.dart';

/// The schema exactly as v9 shipped.
///
/// Captured from `sqlite_master` on 2026-09-28, the last commit before the
/// v10 work. Do not regenerate this from the current schema - the divergence
/// between this and `AppDatabase` is the entire point.
const List<String> kSchemaV9 = <String>[
  '''
CREATE TABLE "app_flags" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("key"));''',
  '''
CREATE TABLE "audit_logs" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "action" TEXT NOT NULL, "entity_type" TEXT NOT NULL, "entity_id" TEXT NOT NULL, "actor_uid" TEXT NOT NULL, "details" TEXT NOT NULL DEFAULT '', "created_at" INTEGER NOT NULL);''',
  '''
CREATE TABLE "print_batches" ("id" TEXT NOT NULL, "school_id" TEXT NOT NULL, "card_count" INTEGER NOT NULL, "sheet_type" TEXT NOT NULL, "sheet_count" INTEGER NOT NULL, "generated_by" TEXT NOT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"));''',
  '''
CREATE TABLE "school_configs" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "address_line" TEXT NOT NULL DEFAULT '', "contact_line" TEXT NOT NULL DEFAULT '', "logo_url" TEXT NULL, "local_logo_path" TEXT NULL, "principal_signature_url" TEXT NULL, "local_principal_signature_path" TEXT NULL, "card_size_id" TEXT NOT NULL DEFAULT 'v54x86', "template_id" TEXT NOT NULL DEFAULT 'default_vertical', "enabled_fields" TEXT NOT NULL DEFAULT '', "primary_color" INTEGER NOT NULL DEFAULT 4292030255, "secondary_color" INTEGER NOT NULL DEFAULT 4279592384, "header_color" INTEGER NOT NULL DEFAULT 4279592384, "photo_background" INTEGER NOT NULL DEFAULT 4294967295, "division_colors" TEXT NOT NULL DEFAULT '{}', "updated_at" INTEGER NULL, PRIMARY KEY ("id"));''',
  '''
CREATE TABLE "student_entries" ("id" TEXT NOT NULL, "school_id" TEXT NOT NULL, "name" TEXT NOT NULL DEFAULT '', "father_name" TEXT NOT NULL DEFAULT '', "student_class" TEXT NOT NULL DEFAULT '', "division" TEXT NOT NULL DEFAULT '', "roll_number" TEXT NOT NULL DEFAULT '', "blood_group" TEXT NOT NULL DEFAULT '', "dob" INTEGER NULL, "mobile" TEXT NOT NULL DEFAULT '', "address" TEXT NOT NULL DEFAULT '', "local_photo_path" TEXT NULL, "remote_photo_url" TEXT NULL, "photo_thumb" TEXT NULL, "sync_status" TEXT NOT NULL DEFAULT 'pending', "sync_attempts" INTEGER NOT NULL DEFAULT 0, "sync_error" TEXT NULL, "last_sync_attempt_at" INTEGER NULL, "details_synced_at" INTEGER NULL, "approval_status" TEXT NOT NULL DEFAULT 'pending', "rejection_reason" TEXT NULL, "reviewed_by" TEXT NULL, "reviewed_at" INTEGER NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));''',
];

/// The schema as v8 shipped: no `photo_thumb`, no `app_flags`.
///
/// This exists so the suite can run a migration that genuinely *does*
/// something. A v9 fixture opened by a v9 database never calls `onUpgrade`
/// at all, so on its own it would prove the harness works and nothing about
/// whether migrations preserve data. Starting one version further back makes
/// the 8 -> 9 step - a column add plus a table create, against populated
/// tables - actually execute.
List<String> get kSchemaV8 => <String>[
  for (final String sql in kSchemaV9)
    if (!sql.contains('"app_flags"'))
      sql.replaceAll('"photo_thumb" TEXT NULL, ', ''),
];

/// The schema as v7 shipped: v8 without `details_synced_at`.
///
/// Needed because 7 -> 8 is the only migration in this project's history that
/// *transforms* data rather than just adding somewhere to put it - it
/// backfills `details_synced_at` from `updated_at`, but only for rows that
/// had already synced. A conditional backfill is the kind that goes wrong
/// quietly, so it is the one worth pinning down.
List<String> get kSchemaV7 => <String>[
  for (final String sql in kSchemaV8)
    sql.replaceAll('"details_synced_at" INTEGER NULL, ', ''),
];

/// An in-memory database sitting at schema [version], with [statements]
/// applied.
///
/// The caller hands the result to `NativeDatabase.opened`, which lets
/// `AppDatabase` open it and run its own `onUpgrade` - the real migration
/// path, not a reimplementation of it.
Database openLegacyDatabase({
  required int version,
  required List<String> statements,
}) {
  final Database db = sqlite3.openInMemory();
  for (final String sql in statements) {
    db.execute(sql);
  }
  // Drift decides whether to migrate by reading this, so a database that
  // claims the wrong version is never upgraded at all - the failure mode
  // this helper exists to avoid.
  db.execute('PRAGMA user_version = $version;');
  return db;
}

/// A `DateTimeColumn` as drift actually stores it: **seconds** since epoch,
/// not milliseconds.
///
/// Verified against a live insert rather than assumed. Getting this wrong
/// does not fail loudly - it writes dates in the year 57000, and the row
/// still reads back, so a migration test would pass while proving nothing.
int secs(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;
