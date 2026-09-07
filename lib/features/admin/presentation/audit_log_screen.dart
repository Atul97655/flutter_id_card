import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/shared/services/local/audit_repository.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Full audit trail viewer: chronological list of all admin actions with
/// filter chips and expandable detail rows.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  static const String routePath = '/admin/audit';

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _selectedFilter = 'all';

  static const Map<String, List<String>> _filterGroups = <String, List<String>>{
    'all': <String>[],
    'approvals': <String>['approve', 'bulk_approve'],
    'rejections': <String>['reject', 'bulk_reject'],
    'exports': <String>['export_csv'],
    'prints': <String>['print_batch'],
    'sync': <String>['sync_pass'],
  };

  @override
  Widget build(BuildContext context) {
    // Watch the right provider based on filter.
    final AsyncValue<List<AuditEntry>> logsAsync = _selectedFilter == 'all'
        ? ref.watch(recentAuditLogsProvider)
        : ref.watch(
            auditLogsByActionsProvider(_filterGroups[_selectedFilter]!));

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: Column(
        children: <Widget>[
          // ── Filter Chips ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.gutter, vertical: 8),
            child: Row(
              children: <Widget>[
                for (final String key in _filterGroups.keys) ...<Widget>[
                  FilterChip(
                    label: Text(_chipLabel(key)),
                    selected: _selectedFilter == key,
                    onSelected: (_) => setState(() => _selectedFilter = key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

          // ── Log List ─────────────────────────────────────────────
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load audit log: $e'),
                ),
              ),
              data: (List<AuditEntry> logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.history,
                            size: 48, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No audit entries yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Actions like approvals, exports, and print runs\n'
                          'will appear here as they happen.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.gutter),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int index) =>
                      _AuditTile(entry: logs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _chipLabel(String key) => switch (key) {
        'all' => 'All',
        'approvals' => 'Approvals',
        'rejections' => 'Rejections',
        'exports' => 'Exports',
        'prints' => 'Print Batches',
        'sync' => 'Sync',
        _ => key,
      };
}

class _AuditTile extends StatefulWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  @override
  State<_AuditTile> createState() => _AuditTileState();
}

class _AuditTileState extends State<_AuditTile> {
  bool _expanded = false;

  static final DateFormat _timeFmt = DateFormat('dd MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final AuditEntry e = widget.entry;
    final ThemeData theme = Theme.of(context);
    final (IconData icon, Color color) = _iconAndColor(e.action);

    return Card(
      child: InkWell(
        onTap: e.details.isNotEmpty
            ? () => setState(() => _expanded = !_expanded)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          e.actionLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${e.entityType} · ${_truncateId(e.entityId)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _timeFmt.format(e.createdAt),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (e.details.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ],
              ),
              if (_expanded && e.details.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(e.details),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _iconAndColor(String action) => switch (action) {
        'approve' || 'bulk_approve' => (Icons.check_circle_outline, StatusColors.synced),
        'reject' || 'bulk_reject' => (Icons.cancel_outlined, StatusColors.failed),
        'export_csv' => (Icons.download_outlined, const Color(0xFF1565C0)),
        'print_batch' => (Icons.print_outlined, const Color(0xFF4527A0)),
        'create_school' => (Icons.school_outlined, const Color(0xFF2E7D32)),
        'update_school' => (Icons.settings_outlined, const Color(0xFF00838F)),
        'sync_pass' => (Icons.sync_outlined, StatusColors.pending),
        _ => (Icons.history, const Color(0xFF757575)),
      };

  static String _truncateId(String id) =>
      id.length > 12 ? '${id.substring(0, 12)}...' : id;
}
