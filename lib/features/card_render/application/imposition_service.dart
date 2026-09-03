import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_id_card/features/admin/domain/imposition.dart';
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One generated file, ready to be written to disk or sent to a printer.
class GeneratedPdf {
  const GeneratedPdf({
    required this.fileName,
    required this.bytes,
    required this.cardCount,
    this.warnings = const <String>[],
  });

  final String fileName;
  final Uint8List bytes;
  final int cardCount;
  final List<String> warnings;
}

/// Builds ganged print sheets from a list of entries.
///
/// Every card on every sheet goes through [IdCardRenderer.buildCard] - the same
/// call the single-card export and the on-screen preview use - so a card cannot
/// look one way in preview and another way 25-up.
class ImpositionService {
  ImpositionService(this._renderer);

  final IdCardRenderer _renderer;

  /// Splits [entries] across as many sheets as needed and returns one PDF per
  /// sheet, named `sheet_001.pdf`, `sheet_002.pdf`, ...
  ///
  /// [namePrefix] lets the A4 output use `a4_001.pdf` without a second method.
  Future<List<GeneratedPdf>> buildSheets({
    required List<StudentEntry> entries,
    required SchoolConfig config,
    required CardTemplate template,
    required CardSize cardSize,
    required SheetSpec sheet,
    double gutterMm = 0,
    bool cropMarks = true,
    String namePrefix = 'sheet',
  }) async {
    final ImpositionGrid grid = ImpositionGrid.compute(
      sheet: sheet,
      cardSize: cardSize,
      gutterMm: gutterMm,
    );

    if (!grid.isUsable) {
      // Nothing can be laid out; hand the warnings back rather than writing an
      // empty PDF the operator would only discover at the printer.
      return <GeneratedPdf>[];
    }

    // Photos are read once and reused across sheets. A 240-student school at
    // 25-up is 10 sheets; re-reading every photo per sheet would be 10x the IO.
    final Map<String, Uint8List> photoCache = <String, Uint8List>{};
    for (final StudentEntry e in entries) {
      final Uint8List? bytes = await _readFile(e.localPhotoPath);
      if (bytes != null) photoCache[e.id] = bytes;
    }
    final Uint8List? logoBytes = await _readFile(config.localLogoPath);

    final List<GeneratedPdf> output = <GeneratedPdf>[];
    final int sheetCount = grid.sheetsFor(entries.length);
    final List<CardSlot> slots = grid.slots;

    for (int sheetIndex = 0; sheetIndex < sheetCount; sheetIndex++) {
      final int start = sheetIndex * grid.capacity;
      final int end = (start + grid.capacity).clamp(0, entries.length);
      final List<StudentEntry> pageEntries = entries.sublist(start, end);

      final Set<String> pageWarnings = <String>{...grid.warnings};

      final pw.Document doc = pw.Document(
        title: '${config.name} - ${sheet.name} ${sheetIndex + 1}',
        author: config.name,
      );

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            PrintUnits.mmToPt(sheet.widthMm),
            PrintUnits.mmToPt(sheet.heightMm),
            marginAll: 0,
          ),
          build: (pw.Context context) {
            final List<pw.Widget> children = <pw.Widget>[];

            for (int i = 0; i < pageEntries.length; i++) {
              final StudentEntry entry = pageEntries[i];
              final CardSlot slot = slots[i];

              final CardRenderPlan plan = IdCardRenderer.planFor(
                entry: entry,
                config: config,
                template: template,
                size: cardSize,
              );
              for (final String w in plan.warnings) {
                pageWarnings.add('${entry.name}: $w');
              }

              children.add(
                pw.Positioned(
                  left: PrintUnits.mmToPt(slot.xMm),
                  top: PrintUnits.mmToPt(slot.yMm),
                  child: _renderer.buildCard(
                    plan: plan,
                    config: config,
                    size: cardSize,
                    photoBytes: photoCache[entry.id],
                    logoBytes: logoBytes,
                  ),
                ),
              );

              if (cropMarks) {
                children.addAll(
                  _renderer.buildCropMarks(
                    cardLeftMm: slot.xMm,
                    cardTopMm: slot.yMm,
                    size: cardSize,
                  ),
                );
              }
            }

            return pw.Stack(children: children);
          },
        ),
      );

      output.add(
        GeneratedPdf(
          fileName: '${namePrefix}_${_pad(sheetIndex + 1)}.pdf',
          bytes: await doc.save(),
          cardCount: pageEntries.length,
          warnings: pageWarnings.toList(),
        ),
      );
    }

    return output;
  }

  /// One PDF per student, at exact card size, for reprints.
  Future<List<GeneratedPdf>> buildSingleCards({
    required List<StudentEntry> entries,
    required SchoolConfig config,
    required CardTemplate template,
    required CardSize cardSize,
    double bleedMm = 0,
    bool cropMarks = false,
  }) async {
    final List<GeneratedPdf> output = <GeneratedPdf>[];
    final Set<String> usedNames = <String>{};

    for (final StudentEntry entry in entries) {
      // Two students can share a name and class; suffix duplicates so the
      // second file does not silently overwrite the first.
      String name = '${entry.exportBaseName}.pdf';
      int suffix = 2;
      while (usedNames.contains(name.toLowerCase())) {
        name = '${entry.exportBaseName}_$suffix.pdf';
        suffix++;
      }
      usedNames.add(name.toLowerCase());

      final CardRenderPlan plan = IdCardRenderer.planFor(
        entry: entry,
        config: config,
        template: template,
        size: cardSize,
      );

      output.add(
        GeneratedPdf(
          fileName: name,
          bytes: await _renderer.buildSingleCardPdf(
            entry: entry,
            config: config,
            template: template,
            size: cardSize,
            bleedMm: bleedMm,
            cropMarks: cropMarks,
          ),
          cardCount: 1,
          warnings: plan.warnings,
        ),
      );
    }

    return output;
  }

  static String _pad(int n) => n.toString().padLeft(3, '0');

  static Future<Uint8List?> _readFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    final File file = File(path);
    if (!file.existsSync()) return null;
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }
}
