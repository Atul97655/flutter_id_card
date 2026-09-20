import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';

/// Domain-friendly view of an audit log entry.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorUid,
    this.details = const <String, Object?>{},
    required this.createdAt,
  });

  final int id;
  final String action;
  final String entityType;
  final String entityId;
  final String actorUid;
  final Map<String, Object?> details;
  final DateTime createdAt;

  /// Human-readable label for the action verb.
  String get actionLabel => switch (action) {
    'approve' => 'Approved',
    'reject' => 'Rejected',
    'bulk_approve' => 'Bulk Approved',
    'bulk_reject' => 'Bulk Rejected',
    'export_csv' => 'CSV Exported',
    'print_batch' => 'Print Batch',
    'create_school' => 'School Created',
    'update_school' => 'School Updated',
    'sync_pass' => 'Sync Pass',
    _ => action,
  };
}

/// All persistence for the immutable audit trail.
///
/// Inserts are fire-and-forget: the caller never awaits them. Queries power
/// the audit log screen and per-entity history views.
class AuditRepository {
  AuditRepository(this._db);

  final AppDatabase _db;

  // ------------------------------------------------------------------
  // Write
  // ------------------------------------------------------------------

  /// Records an admin action. Returns immediately; the insert runs
  /// asynchronously. The caller never needs the result.
  Future<void> log({
    required String action,
    required String entityType,
    required String entityId,
    required String actorUid,
    Map<String, Object?>? details,
  }) async {
    await _db
        .into(_db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            action: action,
            entityType: entityType,
            entityId: entityId,
            actorUid: actorUid,
            details: Value<String>(details != null ? jsonEncode(details) : ''),
            createdAt: DateTime.now(),
          ),
        );
  }

  // ------------------------------------------------------------------
  // Read
  // ------------------------------------------------------------------

  /// Live feed for the audit log screen, newest first.
  Stream<List<AuditEntry>> watchRecent({int limit = 200}) {
    final SimpleSelectStatement<AuditLogs, AuditLogRow> query =
        _db.select(_db.auditLogs)
          ..orderBy(<OrderClauseGenerator<AuditLogs>>[
            (AuditLogs t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            (AuditLogs t) =>
                OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit);
    return query.watch().map(
      (List<AuditLogRow> rows) => rows.map(_toDomain).toList(),
    );
  }

  /// Entries for one specific entity (e.g. one student's approval history).
  Future<List<AuditEntry>> listForEntity(
    String entityType,
    String entityId,
  ) async {
    final List<AuditLogRow> rows =
        await (_db.select(_db.auditLogs)
              ..where(
                (AuditLogs t) =>
                    t.entityType.equals(entityType) &
                    t.entityId.equals(entityId),
              )
              ..orderBy(<OrderClauseGenerator<AuditLogs>>[
                (AuditLogs t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
                (AuditLogs t) =>
                    OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ]))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// Filter by action verb (e.g. 'approve', 'export_csv').
  Future<List<AuditEntry>> listByAction(
    String action, {
    int limit = 100,
  }) async {
    final List<AuditLogRow> rows =
        await (_db.select(_db.auditLogs)
              ..where((AuditLogs t) => t.action.equals(action))
              ..orderBy(<OrderClauseGenerator<AuditLogs>>[
                (AuditLogs t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
                (AuditLogs t) =>
                    OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(limit))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// Filter by multiple action verbs at once (for the chip filter UI).
  Stream<List<AuditEntry>> watchByActions(
    List<String> actions, {
    int limit = 200,
  }) {
    final SimpleSelectStatement<AuditLogs, AuditLogRow> query =
        _db.select(_db.auditLogs)
          ..where((AuditLogs t) => t.action.isIn(actions))
          ..orderBy(<OrderClauseGenerator<AuditLogs>>[
            (AuditLogs t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            (AuditLogs t) =>
                OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit);
    return query.watch().map(
      (List<AuditLogRow> rows) => rows.map(_toDomain).toList(),
    );
  }

  /// Total count of entries for an action verb.
  Future<int> countByAction(String action) async {
    final Expression<int> cnt = _db.auditLogs.id.count();
    final JoinedSelectStatement<AuditLogs, AuditLogRow> query =
        _db.selectOnly(_db.auditLogs)
          ..addColumns(<Expression<Object>>[cnt])
          ..where(_db.auditLogs.action.equals(action));
    final TypedResult row = await query.getSingle();
    return row.read(cnt) ?? 0;
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  static AuditEntry _toDomain(AuditLogRow row) {
    Map<String, Object?> details = const <String, Object?>{};
    if (row.details.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(row.details);
        if (decoded is Map<String, Object?>) {
          details = decoded;
        }
      } on FormatException {
        // Corrupted JSON - just show an empty map rather than crashing.
      }
    }

    return AuditEntry(
      id: row.id,
      action: row.action,
      entityType: row.entityType,
      entityId: row.entityId,
      actorUid: row.actorUid,
      details: details,
      createdAt: row.createdAt,
    );
  }
}
