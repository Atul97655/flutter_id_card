import 'package:drift/drift.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:uuid/uuid.dart';

/// Domain-friendly print batch record.
class PrintBatch {
  const PrintBatch({
    required this.id,
    required this.schoolId,
    required this.cardCount,
    required this.sheetType,
    required this.sheetCount,
    required this.generatedBy,
    required this.createdAt,
  });

  final String id;
  final String schoolId;
  final int cardCount;
  final String sheetType;
  final int sheetCount;
  final String generatedBy;
  final DateTime createdAt;

  /// Human label for the sheet type column.
  String get sheetTypeLabel => switch (sheetType) {
        '12x18' => '12 × 18 in',
        'a4' => 'A4 Landscape',
        'single' => 'Single Cards',
        _ => sheetType,
      };
}

/// Persistence for print batch tracking.
///
/// Each time an admin generates a set of PDFs on the print screen, a batch
/// record is created here. This feeds the print history section on the school
/// detail screen and the export screen.
class PrintBatchRepository {
  PrintBatchRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  // ------------------------------------------------------------------
  // Write
  // ------------------------------------------------------------------

  /// Records a new print batch. Called from the print screen after a successful
  /// generation. Returns the batch id so the caller can log it in the audit
  /// trail.
  Future<String> create({
    required String schoolId,
    required int cardCount,
    required String sheetType,
    required int sheetCount,
    required String generatedBy,
    DateTime? createdAt,
  }) async {
    final String id = _uuid.v4();
    await _db.into(_db.printBatches).insert(
          PrintBatchesCompanion.insert(
            id: id,
            schoolId: schoolId,
            cardCount: cardCount,
            sheetType: sheetType,
            sheetCount: sheetCount,
            generatedBy: generatedBy,
            createdAt: createdAt ?? DateTime.now(),
          ),
        );
    return id;
  }

  // ------------------------------------------------------------------
  // Read
  // ------------------------------------------------------------------

  /// Live list for one school's print history, newest first.
  Stream<List<PrintBatch>> watchBySchool(String schoolId) {
    final SimpleSelectStatement<PrintBatches, PrintBatchRow> query =
        _db.select(_db.printBatches)
          ..where((PrintBatches t) => t.schoolId.equals(schoolId))
          ..orderBy(<OrderClauseGenerator<PrintBatches>>[
            (PrintBatches t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]);
    return query.watch().map(
          (List<PrintBatchRow> rows) => rows.map(_toDomain).toList(),
        );
  }

  /// Global view across all schools, for the export dashboard.
  Stream<List<PrintBatch>> watchAll({int limit = 100}) {
    final SimpleSelectStatement<PrintBatches, PrintBatchRow> query =
        _db.select(_db.printBatches)
          ..orderBy(<OrderClauseGenerator<PrintBatches>>[
            (PrintBatches t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit);
    return query.watch().map(
          (List<PrintBatchRow> rows) => rows.map(_toDomain).toList(),
        );
  }

  /// One-shot count of all batches for a school. Lighter than streaming when
  /// only the number is needed (e.g. a badge on the school card).
  Future<int> countForSchool(String schoolId) async {
    final Expression<int> cnt = _db.printBatches.id.count();
    final JoinedSelectStatement<PrintBatches, PrintBatchRow> query =
        _db.selectOnly(_db.printBatches)
          ..addColumns(<Expression<Object>>[cnt])
          ..where(_db.printBatches.schoolId.equals(schoolId));
    final TypedResult row = await query.getSingle();
    return row.read(cnt) ?? 0;
  }

  /// Total number of cards printed across all batches for a school.
  Future<int> cardCountForSchool(String schoolId) async {
    final Expression<int> sumCards = _db.printBatches.cardCount.sum();
    final JoinedSelectStatement<PrintBatches, PrintBatchRow> query =
        _db.selectOnly(_db.printBatches)
          ..addColumns(<Expression<Object>>[sumCards])
          ..where(_db.printBatches.schoolId.equals(schoolId));
    final TypedResult row = await query.getSingle();
    return row.read(sumCards) ?? 0;
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  static PrintBatch _toDomain(PrintBatchRow row) => PrintBatch(
        id: row.id,
        schoolId: row.schoolId,
        cardCount: row.cardCount,
        sheetType: row.sheetType,
        sheetCount: row.sheetCount,
        generatedBy: row.generatedBy,
        createdAt: row.createdAt,
      );
}
