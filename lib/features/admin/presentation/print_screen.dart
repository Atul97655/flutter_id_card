import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/data/export_service.dart';
import 'package:flutter_id_card/features/admin/domain/imposition.dart';
import 'package:flutter_id_card/features/card_render/application/card_render_providers.dart';
import 'package:flutter_id_card/features/card_render/application/imposition_service.dart';
import 'package:flutter_id_card/features/card_render/data/template_repository.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Generates the three print outputs for a school and writes them to disk.
///
/// Only **approved** entries are offered - that is the whole point of the
/// review step, and it is enforced here in the one place that feeds a printer
/// rather than trusted to the caller.
class PrintScreen extends ConsumerStatefulWidget {
  const PrintScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  ConsumerState<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends ConsumerState<PrintScreen> {
  bool _busy = false;
  String? _status;
  ExportResult? _lastResult;
  bool _cropMarks = true;
  bool _bleed = false;

  @override
  Widget build(BuildContext context) {
    final SchoolConfig? school =
        ref.watch(schoolByIdProvider(widget.schoolId)).value;
    final List<StudentEntry> all =
        ref.watch(entriesForSchoolProvider(widget.schoolId)).value ??
            const <StudentEntry>[];

    final List<StudentEntry> printable = all
        .where((StudentEntry e) => e.isPrintable && e.hasPhoto)
        .toList();
    final int approvedWithoutPhoto =
        all.where((StudentEntry e) => e.isPrintable && !e.hasPhoto).length;

    final CardSize size = school?.cardSize ?? CardSize.defaultSize;
    final ImpositionGrid grid12x18 = ImpositionGrid.compute(
      sheet: SheetSpec.sheet12x18,
      cardSize: size,
    );
    final ImpositionGrid gridA4 = ImpositionGrid.compute(
      sheet: SheetSpec.a4Landscape,
      cardSize: size,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Print & Export')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          _ReadinessCard(
            printable: printable.length,
            total: all.length,
            approvedWithoutPhoto: approvedWithoutPhoto,
            size: size,
          ),
          const SizedBox(height: AppTheme.gutter),

          _OptionsCard(
            cropMarks: _cropMarks,
            bleed: _bleed,
            onCropMarks: (bool v) => setState(() => _cropMarks = v),
            onBleed: (bool v) => setState(() => _bleed = v),
          ),
          const SizedBox(height: AppTheme.gutter),

          _SheetCard(
            title: '12 x 18 in Sheets',
            subtitle: grid12x18.isUsable
                ? '${grid12x18.columns} x ${grid12x18.rows} = '
                    '${grid12x18.capacity} cards per sheet  -  '
                    '${grid12x18.sheetsFor(printable.length)} sheet(s)'
                : 'This card size does not fit',
            warnings: grid12x18.warnings,
            enabled: !_busy && printable.isNotEmpty && grid12x18.isUsable,
            onGenerate: () => _generateSheets(
              school: school,
              entries: printable,
              sheet: SheetSpec.sheet12x18,
              subfolder: ExportService.sheets12x18Dir,
              namePrefix: 'sheet',
            ),
          ),
          const SizedBox(height: 10),

          _SheetCard(
            title: 'A4 Landscape Sheets',
            subtitle: gridA4.isUsable
                ? '${gridA4.columns} x ${gridA4.rows} = ${gridA4.capacity} '
                    'cards per sheet  -  '
                    '${gridA4.sheetsFor(printable.length)} sheet(s)'
                : 'This card size does not fit',
            warnings: gridA4.warnings,
            enabled: !_busy && printable.isNotEmpty && gridA4.isUsable,
            onGenerate: () => _generateSheets(
              school: school,
              entries: printable,
              sheet: SheetSpec.a4Landscape,
              subfolder: ExportService.sheetsA4Dir,
              namePrefix: 'a4',
            ),
          ),
          const SizedBox(height: 10),

          _SheetCard(
            title: 'Single Cards',
            subtitle: 'One PDF per student, named STUDENTNAME_CLASS.pdf '
                '(${printable.length} file(s))',
            warnings: const <String>[],
            enabled: !_busy && printable.isNotEmpty,
            onGenerate: () => _generateSingles(school: school, entries: printable),
          ),

          if (_status != null) ...<Widget>[
            const SizedBox(height: AppTheme.gutter),
            _StatusCard(message: _status!),
          ],

          if (_lastResult != null) ...<Widget>[
            const SizedBox(height: AppTheme.gutter),
            _OutputCard(
              result: _lastResult!,
              onOpenFolder: _openFolder,
              onPrintFile: _printFile,
            ),
          ],

          const SizedBox(height: AppTheme.gutter),
          const _PlatformNoteCard(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Generation
  // ------------------------------------------------------------------

  Future<
      ({
        SchoolConfig config,
        CardTemplate template,
        ImpositionService service,
      })?> _prepare(SchoolConfig? school) async {
    if (school == null) {
      _fail('School settings have not loaded yet.');
      return null;
    }
    final ImpositionService service =
        await ref.read(impositionServiceProvider.future);
    final TemplateRepository repo = ref.read(templateRepositoryProvider);
    final CardTemplate template = await repo.resolve(
      templateId: school.templateId,
      cardSize: school.cardSize,
    );
    return (config: school, template: template, service: service);
  }

  Future<void> _generateSheets({
    required SchoolConfig? school,
    required List<StudentEntry> entries,
    required SheetSpec sheet,
    required String subfolder,
    required String namePrefix,
  }) async {
    setState(() {
      _busy = true;
      _status = 'Generating ${sheet.name}...';
      _lastResult = null;
    });

    try {
      final prepared = await _prepare(school);
      if (prepared == null) return;

      final List<GeneratedPdf> pdfs = await prepared.service.buildSheets(
        entries: entries,
        config: prepared.config,
        template: prepared.template,
        cardSize: prepared.config.cardSize,
        sheet: sheet,
        cropMarks: _cropMarks,
        // Bleed needs a gutter of at least twice the bleed, otherwise adjacent
        // cards' artwork overlaps. Butt-cut (no gutter) is the default.
        gutterMm: _bleed ? PrintUnits.defaultBleedMm * 2 : 0,
        namePrefix: namePrefix,
      );

      if (pdfs.isEmpty) {
        _fail('Nothing was generated - the card size does not fit this sheet.');
        return;
      }

      final ExportResult result = await ref.read(exportServiceProvider).write(
            schoolName: prepared.config.name,
            subfolder: subfolder,
            pdfs: pdfs,
          );

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _status = 'Wrote ${result.fileCount} file(s) to $subfolder.';
      });
    } on Object catch (e) {
      _fail('Generation failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateSingles({
    required SchoolConfig? school,
    required List<StudentEntry> entries,
  }) async {
    setState(() {
      _busy = true;
      _status = 'Generating ${entries.length} single cards...';
      _lastResult = null;
    });

    try {
      final prepared = await _prepare(school);
      if (prepared == null) return;

      final List<GeneratedPdf> pdfs = await prepared.service.buildSingleCards(
        entries: entries,
        config: prepared.config,
        template: prepared.template,
        cardSize: prepared.config.cardSize,
        bleedMm: _bleed ? PrintUnits.defaultBleedMm : 0,
        cropMarks: _cropMarks,
      );

      final ExportResult result = await ref.read(exportServiceProvider).write(
            schoolName: prepared.config.name,
            subfolder: ExportService.singleCardsDir,
            pdfs: pdfs,
          );

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _status = 'Wrote ${result.fileCount} single card(s).';
      });
    } on Object catch (e) {
      _fail('Generation failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _status = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: StatusColors.failed),
      );
  }

  Future<void> _openFolder() async {
    final ExportResult? result = _lastResult;
    if (result == null) return;

    final bool ok = await ref.read(exportServiceProvider).openFolder(result.directory);
    if (!mounted || ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ExportService.canOpenFolder
              ? 'Could not open the folder.'
              : 'Opening a folder is only supported on the desktop build. '
                  'Files are at ${result.directory.path}',
        ),
      ),
    );
  }

  Future<void> _printFile(File file) async {
    try {
      await ref.read(exportServiceProvider).printOne(file);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.printable,
    required this.total,
    required this.approvedWithoutPhoto,
    required this.size,
  });

  final int printable;
  final int total;
  final int approvedWithoutPhoto;
  final CardSize size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool ready = printable > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ready ? Icons.check_circle_outline : Icons.info_outline,
                  color: ready ? StatusColors.synced : StatusColors.pending,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ready
                        ? '$printable card(s) ready to print'
                        : 'Nothing is ready to print yet',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Only approved entries with a photo are printed. '
              '$total total in this school.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (approvedWithoutPhoto > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '$approvedWithoutPhoto approved entr(ies) have no photo and are '
                'excluded - a card with an empty photo box would waste the sheet.',
                style: const TextStyle(fontSize: 12, color: StatusColors.pending),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Card size: ${size.label}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.cropMarks,
    required this.bleed,
    required this.onCropMarks,
    required this.onBleed,
  });

  final bool cropMarks;
  final bool bleed;
  final ValueChanged<bool> onCropMarks;
  final ValueChanged<bool> onBleed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          SwitchListTile(
            dense: true,
            title: const Text('Crop marks'),
            subtitle: const Text(
              'Corner guides for the guillotine operator',
              style: TextStyle(fontSize: 11.5),
            ),
            value: cropMarks,
            onChanged: onCropMarks,
          ),
          SwitchListTile(
            dense: true,
            title: const Text('3 mm bleed'),
            subtitle: const Text(
              'Adds a gutter between cards so a slightly off cut never shows '
              'white paper. Fewer cards per sheet.',
              style: TextStyle(fontSize: 11.5),
            ),
            value: bleed,
            onChanged: onBleed,
          ),
        ],
      ),
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.title,
    required this.subtitle,
    required this.warnings,
    required this.enabled,
    required this.onGenerate,
  });

  final String title;
  final String subtitle;
  final List<String> warnings;
  final bool enabled;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            for (final String w in warnings) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: StatusColors.pending,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: StatusColors.pending,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: enabled ? onGenerate : null,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.result,
    required this.onOpenFolder,
    required this.onPrintFile,
  });

  final ExportResult result;
  final VoidCallback onOpenFolder;
  final void Function(File) onPrintFile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Generated files',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(
              result.directory.path,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            for (final String w in result.warnings) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                w,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: StatusColors.pending,
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...result.files.take(12).map(
                  (File f) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf, size: 20),
                    title: Text(
                      f.uri.pathSegments.last,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    trailing: IconButton(
                      tooltip: 'Print this file',
                      icon: const Icon(Icons.print_outlined, size: 20),
                      onPressed: () => onPrintFile(f),
                    ),
                  ),
                ),
            if (result.files.length > 12)
              Text(
                '... and ${result.files.length - 12} more',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onOpenFolder,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open folder'),
                ),
                const SizedBox(width: 10),
                if (result.files.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => Printing.layoutPdf(
                      name: result.files.first.uri.pathSegments.last,
                      onLayout: (_) => result.files.first.readAsBytes(),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print first'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformNoteCard extends StatelessWidget {
  const _PlatformNoteCard();

  @override
  Widget build(BuildContext context) {
    // Stated up front rather than letting a button quietly do nothing on
    // Android - bulk printing genuinely needs a desktop OS.
    final bool desktop = ExportService.canOpenFolder;

    return Card(
      color: desktop ? null : const Color(0xFFFFF4E5),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              desktop ? Icons.desktop_windows_outlined : Icons.phone_android,
              size: 18,
              color: desktop ? null : const Color(0xFFE65100),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                desktop
                    ? 'Desktop build: "Open folder" and direct printing are '
                        'available.'
                    : 'On Android there is no file manager intent for a folder '
                        'and no default printer, so "Open folder" and bulk '
                        'printing are unavailable. Files are still written to '
                        'app storage, and each file can be printed or shared '
                        'individually. Use the Windows build for print runs.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: desktop ? null : const Color(0xFF8D4B00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
