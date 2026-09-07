import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';

/// Local cache of per-school settings.
///
/// The data-entry app reads its form configuration from here, never straight
/// from Firestore. Firestore updates are written into this cache by the sync
/// service, which means a school whose settings changed while they were offline
/// keeps using the last-known-good config instead of falling back to defaults.
class SchoolRepository {
  SchoolRepository(this._db);

  final AppDatabase _db;

  Stream<SchoolConfig?> watch(String schoolId) {
    final SimpleSelectStatement<SchoolConfigs, SchoolConfigRow> query =
        _db.select(_db.schoolConfigs)
          ..where((SchoolConfigs t) => t.id.equals(schoolId))
          ..limit(1);
    return query
        .watchSingleOrNull()
        .map((SchoolConfigRow? row) => row == null ? null : _toDomain(row));
  }

  Future<SchoolConfig?> find(String schoolId) async {
    final SchoolConfigRow? row = await (_db.select(_db.schoolConfigs)
          ..where((SchoolConfigs t) => t.id.equals(schoolId))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<SchoolConfig>> listAll() async {
    final List<SchoolConfigRow> rows = await (_db.select(_db.schoolConfigs)
          ..orderBy(<OrderClauseGenerator<SchoolConfigs>>[
            (SchoolConfigs t) => OrderingTerm(expression: t.name),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Stream<List<SchoolConfig>> watchAll() {
    final SimpleSelectStatement<SchoolConfigs, SchoolConfigRow> query =
        _db.select(_db.schoolConfigs)
          ..orderBy(<OrderClauseGenerator<SchoolConfigs>>[
            (SchoolConfigs t) => OrderingTerm(expression: t.name),
          ]);
    return query
        .watch()
        .map((List<SchoolConfigRow> rows) => rows.map(_toDomain).toList());
  }

  Future<void> save(SchoolConfig config) async {
    await _db.into(_db.schoolConfigs).insertOnConflictUpdate(_toCompanion(config));
  }

  Future<void> saveAll(List<SchoolConfig> configs) async {
    await _db.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        _db.schoolConfigs,
        configs.map(_toCompanion).toList(),
      );
    });
  }

  Future<void> delete(String schoolId) async {
    await (_db.delete(_db.schoolConfigs)
          ..where((SchoolConfigs t) => t.id.equals(schoolId)))
        .go();
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  /// Splits the comma-joined field keys. Guards the empty-string case, which
  /// would otherwise produce a set containing one empty key and switch every
  /// field off.
  static Set<String> decodeFieldKeys(String raw) => raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toSet();

  static String encodeFieldKeys(Set<String> keys) => (keys.toList()..sort()).join(',');

  /// Division colours are stored as a JSON object of division -> ARGB int.
  /// Malformed JSON decodes to an empty map so a corrupted row falls back to
  /// the school colour instead of failing the read.
  static Map<String, int> decodeDivisionColors(String raw) {
    if (raw.trim().isEmpty) return const <String, int>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const <String, int>{};
      final Map<String, int> result = <String, int>{};
      for (final MapEntry<String, Object?> e in decoded.entries) {
        final Object? value = e.value;
        if (value is int) result[e.key.toUpperCase()] = value;
      }
      return result;
    } on FormatException {
      return const <String, int>{};
    }
  }

  static String encodeDivisionColors(Map<String, int> colors) =>
      colors.isEmpty ? '{}' : jsonEncode(colors);

  static SchoolConfig _toDomain(SchoolConfigRow row) => SchoolConfig(
        id: row.id,
        name: row.name,
        addressLine: row.addressLine,
        contactLine: row.contactLine,
        logoUrl: row.logoUrl,
        localLogoPath: row.localLogoPath,
        principalSignatureUrl: row.principalSignatureUrl,
        localPrincipalSignaturePath: row.localPrincipalSignaturePath,
        cardSizeId: row.cardSizeId,
        templateId: row.templateId,
        enabledFieldKeys: decodeFieldKeys(row.enabledFields),
        primaryColorHex: row.primaryColor,
        secondaryColorHex: row.secondaryColor,
        headerColorHex: row.headerColor,
        photoBackgroundHex: row.photoBackground,
        divisionColors: decodeDivisionColors(row.divisionColors),
        updatedAt: row.updatedAt,
      );

  static SchoolConfigsCompanion _toCompanion(SchoolConfig c) => SchoolConfigsCompanion(
        id: Value<String>(c.id),
        name: Value<String>(c.name),
        addressLine: Value<String>(c.addressLine),
        contactLine: Value<String>(c.contactLine),
        logoUrl: Value<String?>(c.logoUrl),
        localLogoPath: Value<String?>(c.localLogoPath),
        principalSignatureUrl: Value<String?>(c.principalSignatureUrl),
        localPrincipalSignaturePath: Value<String?>(c.localPrincipalSignaturePath),
        cardSizeId: Value<String>(c.cardSizeId),
        templateId: Value<String>(c.templateId),
        enabledFields: Value<String>(encodeFieldKeys(c.enabledFieldKeys)),
        primaryColor: Value<int>(c.primaryColorHex),
        secondaryColor: Value<int>(c.secondaryColorHex),
        headerColor: Value<int>(c.headerColorHex),
        photoBackground: Value<int>(c.photoBackgroundHex),
        divisionColors: Value<String>(encodeDivisionColors(c.divisionColors)),
        updatedAt: Value<DateTime?>(c.updatedAt),
      );
}
