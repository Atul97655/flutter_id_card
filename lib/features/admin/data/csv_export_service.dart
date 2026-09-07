import 'dart:convert';
import 'dart:io';

import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// What a CSV export produced.
class CsvExportResult {
  const CsvExportResult({
    required this.file,
    required this.rowCount,
    required this.schoolName,
  });

  final File file;
  final int rowCount;
  final String schoolName;
}

/// Generates CSV files from student entry data.
///
/// No external CSV library is needed - the RFC 4180 rules are simple enough
/// for a hand-rolled encoder, and avoiding a dependency keeps the binary
/// smaller and eliminates a version-conflict surface.
class CsvExportService {
  CsvExportService();

  static const String _exportDir = 'Exports';

  /// Column headers in the order they appear in the CSV.
  static const List<String> headers = <String>[
    'Name',
    "Father's Name",
    'Class',
    'Division',
    'Blood Group',
    'Date of Birth',
    'Mobile',
    'Address',
    'Approval Status',
    'Sync Status',
    'Created At',
  ];

  /// Exports entries as a CSV file. Returns the file and row count.
  ///
  /// [schoolName] is used for the filename. [entries] are the rows to export,
  /// already filtered by the caller (the service is filter-agnostic on purpose
  /// so the UI can combine school + status + class filters freely without this
  /// layer needing to know about every permutation).
  Future<CsvExportResult> export({
    required String schoolName,
    required List<StudentEntry> entries,
    String? filterLabel,
  }) async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(base.path, _exportDir));
    await dir.create(recursive: true);

    final String sanitised = sanitiseFilename(schoolName);
    final String timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final String suffix = filterLabel != null ? '_$filterLabel' : '';
    final String filename = '$sanitised${suffix}_$timestamp.csv';
    final File file = File(p.join(dir.path, filename));

    final String content = buildCsvContent(entries);
    await file.writeAsString(content, encoding: utf8, flush: true);

    return CsvExportResult(
      file: file,
      rowCount: entries.length,
      schoolName: schoolName,
    );
  }

  /// Builds the full CSV string including UTF-8 BOM, headers, and escaped data rows.
  static String buildCsvContent(List<StudentEntry> entries) {
    final StringBuffer buffer = StringBuffer();

    // BOM for Excel to recognise UTF-8 on Windows.
    buffer.write('\uFEFF');

    // Header row.
    buffer.writeln(headers.map(escapeField).join(','));

    // Data rows.
    for (final StudentEntry e in entries) {
      final List<String> row = <String>[
        e.name,
        e.fatherName,
        e.studentClass,
        e.division,
        e.bloodGroup,
        e.formattedDob,
        e.mobile,
        e.address,
        e.approvalStatus.name.toUpperCase(),
        e.syncStatus.name.toUpperCase(),
        e.createdAt.toIso8601String(),
      ];
      buffer.writeln(row.map(escapeField).join(','));
    }
    return buffer.toString();
  }

  /// RFC 4180 field escaping: if the value contains a comma, double-quote,
  /// or newline, wrap it in double-quotes and double any internal quotes.
  static String escapeField(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Strips characters illegal in a Windows filename.
  static String sanitiseFilename(String raw) {
    final String cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'Export' : cleaned;
  }
}
