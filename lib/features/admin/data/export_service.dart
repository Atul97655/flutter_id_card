import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_id_card/features/card_render/application/imposition_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Where a batch of generated PDFs ended up.
class ExportResult {
  const ExportResult({
    required this.directory,
    required this.files,
    required this.warnings,
  });

  final Directory directory;
  final List<File> files;
  final List<String> warnings;

  int get fileCount => files.length;
}

/// Writes generated PDFs to disk in the layout the specification requires:
///
/// ```
/// <base>/Output/<SchoolName>/12x18_Sheets/sheet_001.pdf
///                           /A4_Sheets/a4_001.pdf
///                           /Single_Cards/STUDENTNAME_CLASS.pdf
/// ```
///
/// PLATFORM NOTE - this matters for how the admin panel is deployed.
/// "Open folder" and "Print all" are desktop-only capabilities:
///   * There is no file-manager intent on Android that reliably opens a
///     directory, so [canOpenFolder] is false there and the UI must offer
///     "share" or per-file open instead of a dead button.
///   * Android has no concept of a default printer or a silent print queue.
///     [canPrintDirectly] is false, and printing goes through the system print
///     dialog one document at a time.
/// The bulk-print workflow is therefore intended for the Windows/desktop build
/// of the admin panel. Both flags are checked by the UI rather than assumed.
class ExportService {
  ExportService();

  static const String outputRootName = 'Output';
  static const String sheets12x18Dir = '12x18_Sheets';
  static const String sheetsA4Dir = 'A4_Sheets';
  static const String singleCardsDir = 'Single_Cards';

  /// True where a directory can actually be revealed to the user.
  static bool get canOpenFolder =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// True where a document can be sent to a printer without a per-file dialog.
  static bool get canPrintDirectly => canOpenFolder;

  /// Root of the export tree.
  ///
  /// Uses the app documents directory, which is writable without a storage
  /// permission on every supported platform. On Windows that is the user's
  /// Documents folder, which is also where an operator would look for it.
  Future<Directory> outputRoot() async {
    final Directory base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, outputRootName));
  }

  Future<Directory> schoolDirectory(String schoolName) async {
    final Directory root = await outputRoot();
    return Directory(p.join(root.path, _sanitise(schoolName)));
  }

  /// Creates `<Output>/<School>/<subfolder>` and writes every file into it.
  ///
  /// Existing files with the same name are overwritten: regenerating a sheet
  /// after fixing a typo should replace it, not accumulate `sheet_001 (2).pdf`.
  Future<ExportResult> write({
    required String schoolName,
    required String subfolder,
    required List<GeneratedPdf> pdfs,
  }) async {
    final Directory school = await schoolDirectory(schoolName);
    final Directory target = Directory(p.join(school.path, subfolder));
    await target.create(recursive: true);

    final List<File> written = <File>[];
    final Set<String> warnings = <String>{};

    for (final GeneratedPdf pdf in pdfs) {
      final File file = File(p.join(target.path, _sanitise(pdf.fileName)));
      await file.writeAsBytes(pdf.bytes, flush: true);
      written.add(file);
      warnings.addAll(pdf.warnings);
    }

    return ExportResult(
      directory: target,
      files: written,
      warnings: warnings.toList(),
    );
  }

  /// Reveals a folder in the platform file manager.
  ///
  /// Returns false where the platform cannot do it, so the caller can explain
  /// rather than appearing to do nothing.
  Future<bool> openFolder(Directory directory) async {
    if (!canOpenFolder) return false;
    final OpenResult result = await OpenFilex.open(directory.path);
    return result.type == ResultType.done;
  }

  Future<bool> openFile(File file) async {
    final OpenResult result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

  /// Sends every file straight to [printer], with no dialog per document.
  ///
  /// The printer is chosen once by the caller (see `Printing.pickPrinter`,
  /// which needs a BuildContext and therefore belongs in the UI layer) and
  /// reused for the whole batch - prompting per file makes a 10-sheet run
  /// unusable.
  ///
  /// Returns how many documents were accepted by the spooler. A short count
  /// means some failed and the caller should say so rather than reporting
  /// success.
  Future<int> printAll(List<File> files, {required Printer printer}) async {
    if (!canPrintDirectly) return 0;

    int printed = 0;
    for (final File file in files) {
      final bool ok = await Printing.directPrintPdf(
        printer: printer,
        name: p.basename(file.path),
        onLayout: (_) async => file.readAsBytes(),
      );
      if (ok) printed++;
    }
    return printed;
  }

  /// Opens the system print dialog for a single document. Works everywhere,
  /// including Android, and is the fallback the UI offers on mobile.
  Future<void> printOne(File file, {String? name}) async {
    await Printing.layoutPdf(
      name: name ?? p.basename(file.path),
      onLayout: (_) async => file.readAsBytes(),
    );
  }

  /// Strips characters that are illegal in a Windows path, since the export
  /// tree is most often read on a Windows print workstation.
  static String _sanitise(String raw) {
    final String cleaned = raw
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Windows also rejects a trailing dot or space on a path segment.
    final String trimmed = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
    return trimmed.isEmpty ? 'Unnamed' : trimmed;
  }
}
