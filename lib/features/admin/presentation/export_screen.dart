import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/data/csv_export_service.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';

import 'package:flutter_id_card/shared/services/local/print_batch_repository.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

/// Export dashboard: CSV generation, filter controls, and print batch history.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ApprovalStatus? _statusFilter;
  String? _classFilter;
  String? _divisionFilter;
  bool _busy = false;
  CsvExportResult? _lastResult;

  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final SchoolConfig? school =
        ref.watch(schoolByIdProvider(widget.schoolId)).value;
    final List<StudentEntry> allEntries =
        ref.watch(entriesForSchoolProvider(widget.schoolId)).value ??
            const <StudentEntry>[];
    final List<PrintBatch> batches =
        ref.watch(printBatchesForSchoolProvider(widget.schoolId)).value ??
            const <PrintBatch>[];

    final List<StudentEntry> filtered = _applyFilters(allEntries);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Export & Reports')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          // ── Quick Stats ──────────────────────────────────────────
          _QuickStatsCard(
            total: allEntries.length,
            filtered: filtered.length,
            filterLabel: _filterLabel,
          ),
          const SizedBox(height: AppTheme.gutter),

          // ── Filters ──────────────────────────────────────────────
          Text(
            'CSV Export',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _FilterSection(
            statusFilter: _statusFilter,
            classFilter: _classFilter,
            divisionFilter: _divisionFilter,
            classes: school?.classes ?? SchoolConfig.defaultClasses,
            divisions: school?.divisions ?? SchoolConfig.defaultDivisions,
            onStatusChanged: (ApprovalStatus? v) =>
                setState(() => _statusFilter = v),
            onClassChanged: (String? v) => setState(() => _classFilter = v),
            onDivisionChanged: (String? v) =>
                setState(() => _divisionFilter = v),
          ),
          const SizedBox(height: 12),

          // ── Export Button ────────────────────────────────────────
          FilledButton.icon(
            onPressed: _busy || filtered.isEmpty
                ? null
                : () => _exportCsv(school, filtered),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(
              _busy
                  ? 'Exporting...'
                  : 'Export ${filtered.length} record(s) as CSV',
            ),
          ),

          if (_lastResult != null) ...<Widget>[
            const SizedBox(height: 12),
            _ExportResultCard(
              result: _lastResult!,
              onOpen: () => OpenFilex.open(_lastResult!.file.path),
            ),
          ],

          const SizedBox(height: AppTheme.gutter * 1.5),

          // ── Print Batch History ──────────────────────────────────
          Text(
            'Print Batch History',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (batches.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.print_disabled_outlined,
                        size: 36, color: theme.colorScheme.outline),
                    const SizedBox(height: 8),
                    Text(
                      'No print batches yet',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            ...batches.map(
              (PrintBatch b) => Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.print_outlined,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  title: Text(
                    '${b.cardCount} cards · ${b.sheetTypeLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${b.sheetCount} sheet(s) · ${_dateFmt.format(b.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      color: theme.colorScheme.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Filtering
  // ------------------------------------------------------------------

  List<StudentEntry> _applyFilters(List<StudentEntry> entries) {
    Iterable<StudentEntry> result = entries;

    if (_statusFilter != null) {
      result =
          result.where((StudentEntry e) => e.approvalStatus == _statusFilter);
    }
    if (_classFilter != null && _classFilter!.isNotEmpty) {
      result = result.where((StudentEntry e) =>
          e.studentClass.trim().toUpperCase() ==
          _classFilter!.trim().toUpperCase());
    }
    if (_divisionFilter != null && _divisionFilter!.isNotEmpty) {
      result = result.where((StudentEntry e) =>
          e.division.trim().toUpperCase() ==
          _divisionFilter!.trim().toUpperCase());
    }

    return result.toList();
  }

  String get _filterLabel {
    final List<String> parts = <String>[];
    if (_statusFilter != null) parts.add(_statusFilter!.name);
    if (_classFilter != null) parts.add('Class_$_classFilter');
    if (_divisionFilter != null) parts.add('Div_$_divisionFilter');
    return parts.isEmpty ? 'All' : parts.join('_');
  }

  // ------------------------------------------------------------------
  // Export
  // ------------------------------------------------------------------

  Future<void> _exportCsv(
      SchoolConfig? school, List<StudentEntry> entries) async {
    setState(() {
      _busy = true;
      _lastResult = null;
    });

    try {
      final CsvExportService service = ref.read(csvExportServiceProvider);
      final CsvExportResult result = await service.export(
        schoolName: school?.name ?? 'School',
        entries: entries,
        filterLabel: _filterLabel,
      );

      // Audit log the export.
      await ref.read(auditRepositoryProvider).log(
            action: 'export_csv',
            entityType: 'school',
            entityId: widget.schoolId,
            actorUid: ref.read(currentSessionProvider)?.uid ?? 'admin',
            details: <String, Object?>{
              'schoolName': school?.name,
              'rowCount': result.rowCount,
              'filter': _filterLabel,
              'filePath': result.file.path,
            },
          );

      if (!mounted) return;
      setState(() => _lastResult = result);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Exported ${result.rowCount} record(s) to CSV'),
            backgroundColor: StatusColors.synced,
          ),
        );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: StatusColors.failed,
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ====================================================================
// Private widgets
// ====================================================================

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({
    required this.total,
    required this.filtered,
    required this.filterLabel,
  });

  final int total;
  final int filtered;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.table_chart_outlined,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$filtered of $total records',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Filter: $filterLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.statusFilter,
    required this.classFilter,
    required this.divisionFilter,
    required this.classes,
    required this.divisions,
    required this.onStatusChanged,
    required this.onClassChanged,
    required this.onDivisionChanged,
  });

  final ApprovalStatus? statusFilter;
  final String? classFilter;
  final String? divisionFilter;
  final List<String> classes;
  final List<String> divisions;
  final ValueChanged<ApprovalStatus?> onStatusChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onDivisionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Status filter chips
            Text('Status',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilterChip(
                  label: const Text('All'),
                  selected: statusFilter == null,
                  onSelected: (_) => onStatusChanged(null),
                ),
                for (final ApprovalStatus s in ApprovalStatus.values)
                  FilterChip(
                    label: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                    selected: statusFilter == s,
                    onSelected: (_) =>
                        onStatusChanged(statusFilter == s ? null : s),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Class dropdown
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: classFilter,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Classes'),
                      ),
                      for (final String c in classes)
                        DropdownMenuItem<String?>(
                          value: c,
                          child: Text(c),
                        ),
                    ],
                    onChanged: onClassChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: divisionFilter,
                    decoration: const InputDecoration(
                      labelText: 'Division',
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Divisions'),
                      ),
                      for (final String d in divisions)
                        DropdownMenuItem<String?>(
                          value: d,
                          child: Text(d),
                        ),
                    ],
                    onChanged: onDivisionChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportResultCard extends StatelessWidget {
  const _ExportResultCard({
    required this.result,
    required this.onOpen,
  });

  final CsvExportResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle, size: 18, color: StatusColors.synced),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.rowCount} record(s) exported',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              result.file.path,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open file'),
            ),
          ],
        ),
      ),
    );
  }
}
