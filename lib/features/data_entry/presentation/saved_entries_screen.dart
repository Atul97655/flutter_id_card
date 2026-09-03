import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/sync_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Everything captured on this device for the active school.
///
/// Reads straight from the local database, so it works with no connectivity -
/// which is the whole point of the offline-first design.
class SavedEntriesScreen extends ConsumerStatefulWidget {
  const SavedEntriesScreen({super.key});

  @override
  ConsumerState<SavedEntriesScreen> createState() => _SavedEntriesScreenState();
}

class _SavedEntriesScreenState extends ConsumerState<SavedEntriesScreen> {
  final TextEditingController _search = TextEditingController();
  SyncStatus? _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StudentEntry> _applyFilters(List<StudentEntry> all) {
    final String needle = _search.text.trim().toUpperCase();
    return all.where((StudentEntry e) {
      if (_statusFilter != null && e.syncStatus != _statusFilter) return false;
      if (needle.isEmpty) return true;
      return e.name.contains(needle) ||
          e.studentClass.contains(needle) ||
          e.division.contains(needle) ||
          e.mobile.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StudentEntry>> entriesAsync = ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Entries')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => Center(child: Text('Could not load entries: $e')),
        data: (List<StudentEntry> all) {
          final List<StudentEntry> filtered = _applyFilters(all);
          return Column(
            children: <Widget>[
              _filterBar(all),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(hasAny: all.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.gutter),
                        itemCount: filtered.length,
                        separatorBuilder: (BuildContext _, int _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int i) => _EntryTile(
                          entry: filtered[i],
                          onEdit: () => context.push('/entry/${filtered[i].id}'),
                          onPreview: () => context.push('/preview/${filtered[i].id}'),
                          onDelete: () => _confirmDelete(filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterBar(List<StudentEntry> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 12, AppTheme.gutter, 12),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Search name, class, div or mobile',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _statusChip(null, 'All', all.length),
                for (final SyncStatus s in SyncStatus.values)
                  _statusChip(
                    s,
                    s.label,
                    all.where((StudentEntry e) => e.syncStatus == s).length,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(SyncStatus? status, String label, int count) {
    final bool selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() => _statusFilter = selected ? null : status),
        showCheckmark: false,
      ),
    );
  }

  Future<void> _confirmDelete(StudentEntry entry) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          entry.syncStatus == SyncStatus.synced
              ? '${entry.name} has already uploaded. Deleting here removes the '
                  'local copy only - the record stays on the server.'
              : '${entry.name} has not uploaded yet. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StatusColors.failed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(studentRepositoryProvider).delete(entry.id);
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
  });

  final StudentEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = entry.localPhotoPath;
    final bool hasThumb = path != null && path.isNotEmpty && File(path).existsSync();

    return Card(
      child: InkWell(
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 60, // 1.2:1.5
                  child: hasThumb
                      ? Image.file(File(path), fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_outline,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name.isEmpty ? 'UNNAMED' : entry.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (entry.studentClass.isNotEmpty) 'Class ${entry.studentClass}',
                        if (entry.division.isNotEmpty) 'Div ${entry.division}',
                        if (entry.mobile.isNotEmpty) entry.mobile,
                      ].join('  -  '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        SyncStatusChip(status: entry.syncStatus, dense: true),
                        if (entry.syncError != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.syncError!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: StatusColors.failed,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (String value) => switch (value) {
                  'edit' => onEdit(),
                  'preview' => onPreview(),
                  'delete' => onDelete(),
                  _ => null,
                },
                itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'preview',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Preview card'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline, color: StatusColors.failed),
                      title: Text('Delete', style: TextStyle(color: StatusColors.failed)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});

  /// Distinguishes "no entries at all" from "your filter matched nothing",
  /// which need different advice.
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              hasAny ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
              size: 52,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              hasAny ? 'No entries match your filter' : 'No entries yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasAny
                  ? 'Clear the search box or pick a different status.'
                  : 'Tap "New ID Card" on the home screen to add the first one.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
