import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_id_card/shared/widgets/sync_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// My Submissions - everything this operator has captured, and what the office
/// decided about each one.
///
/// Filters on **approval** status, not sync status. That is the question a
/// teacher actually has ("did it get approved?"); sync state only matters when
/// something is stuck, so it stays as a secondary chip on the row instead of
/// the primary axis it used to be.
class SavedEntriesScreen extends ConsumerStatefulWidget {
  const SavedEntriesScreen({super.key});

  @override
  ConsumerState<SavedEntriesScreen> createState() => _SavedEntriesScreenState();
}

class _SavedEntriesScreenState extends ConsumerState<SavedEntriesScreen> {
  final TextEditingController _search = TextEditingController();

  /// Null means "All".
  ApprovalStatus? _filter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StudentEntry> _applyFilters(List<StudentEntry> all) {
    final String needle = _search.text.trim().toUpperCase();
    return all.where((StudentEntry e) {
      if (_filter != null && e.approvalStatus != _filter) return false;
      if (needle.isEmpty) return true;
      return e.name.contains(needle) ||
          e.studentClass.contains(needle) ||
          e.division.contains(needle) ||
          e.rollNumber.contains(needle) ||
          e.mobile.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StudentEntry>> entriesAsync =
        ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Submissions')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) =>
            Center(child: Text('Could not load submissions: $e')),
        data: (List<StudentEntry> all) {
          final List<StudentEntry> filtered = _applyFilters(all);
          return Column(
            children: <Widget>[
              _filterBar(all),
              const Divider(height: 1),
              Expanded(
                child: SmoothSwitcher(
                  child: filtered.isEmpty
                      ? _EmptyState(
                          key: ValueKey<String>('empty-${_filter?.name}'),
                          hasAny: all.isNotEmpty,
                          filter: _filter,
                        )
                      : ListView.separated(
                          key: ValueKey<String>(
                            'list-${_filter?.name}-${filtered.length}',
                          ),
                          padding: const EdgeInsets.all(AppTheme.gutter),
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext _, int _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) =>
                              FadeSlideIn(
                            index: i,
                            child: _EntryTile(
                              entry: filtered[i],
                              onOpen: () =>
                                  context.push('/submissions/${filtered[i].id}'),
                              onEdit: () =>
                                  context.push('/entry/${filtered[i].id}'),
                              onPreview: () =>
                                  context.push('/preview/${filtered[i].id}'),
                              onDelete: () => _confirmDelete(filtered[i]),
                            ),
                          ),
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
      padding:
          const EdgeInsets.fromLTRB(AppTheme.gutter, 12, AppTheme.gutter, 12),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Search name, class, div, roll or mobile',
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
                // Order matches the journey a card takes, so the tabs read
                // left-to-right as progress.
                for (final ApprovalStatus s in <ApprovalStatus>[
                  ApprovalStatus.pending,
                  ApprovalStatus.approved,
                  ApprovalStatus.printed,
                  ApprovalStatus.rejected,
                ])
                  _statusChip(
                    s,
                    s.label,
                    all
                        .where((StudentEntry e) => e.approvalStatus == s)
                        .length,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ApprovalStatus? status, String label, int count) {
    final bool selected = _filter == status;
    final Color? tint = status == null
        ? null
        : ApprovalStatusChip.visualsFor(status).$1;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) =>
            setState(() => _filter = selected ? null : status),
        showCheckmark: false,
        selectedColor: tint?.withValues(alpha: 0.16),
        side: selected && tint != null
            ? BorderSide(color: tint.withValues(alpha: 0.5))
            : null,
        labelStyle: selected && tint != null
            ? TextStyle(color: tint, fontWeight: FontWeight.w700)
            : null,
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
    required this.onOpen,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
  });

  final StudentEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = entry.localPhotoPath;
    final bool hasThumb =
        path != null && path.isNotEmpty && File(path).existsSync();
    final bool rejected = entry.approvalStatus.needsOperatorAttention;

    return PressableSurface(
      onTap: onOpen,
      child: Card(
        // A sent-back card gets a red edge so it is findable in a long list
        // without reading every status chip.
        shape: rejected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                side: BorderSide(
                  color: StatusColors.failed.withValues(alpha: 0.45),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Hero(
                tag: 'entry-photo-${entry.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 60, // 1.2:1.5
                    child: hasThumb
                        ? Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            cacheHeight: 200,
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.person_outline,
                              color: theme.colorScheme.outline,
                            ),
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
                        if (entry.studentClass.isNotEmpty)
                          'Class ${entry.studentClass}',
                        if (entry.division.isNotEmpty) 'Div ${entry.division}',
                        if (entry.rollNumber.isNotEmpty)
                          'Roll ${entry.rollNumber}',
                      ].join('  ·  '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ApprovalStatusChip(
                          status: entry.approvalStatus,
                          dense: true,
                        ),
                        // Sync state is only worth the space when it is not
                        // the happy path - a synced row says nothing useful.
                        if (entry.syncStatus != SyncStatus.synced)
                          SyncStatusChip(status: entry.syncStatus, dense: true),
                      ],
                    ),
                    if (rejected && entry.rejectionReason != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        entry.rejectionReason!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: StatusColors.failed,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (String value) => switch (value) {
                  'open' => onOpen(),
                  'edit' => onEdit(),
                  'preview' => onPreview(),
                  'delete' => onDelete(),
                  _ => null,
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'open',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.receipt_long_outlined),
                      title: Text('View status'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'preview',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Preview card'),
                    ),
                  ),
                  // Editing an approved card would invalidate one that may
                  // already be printed and in a school's hands.
                  if (!entry.approvalStatus.isApproved)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.delete_outline, color: StatusColors.failed),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: StatusColors.failed),
                      ),
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
  const _EmptyState({super.key, required this.hasAny, required this.filter});

  /// Distinguishes "no entries at all" from "your filter matched nothing",
  /// which need different advice.
  final bool hasAny;
  final ApprovalStatus? filter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (IconData icon, String title, String body) = switch ((
      hasAny,
      filter,
    )) {
      (false, _) => (
          Icons.inbox_outlined,
          'No submissions yet',
          'Tap "New ID Card" on the home screen to add the first one.',
        ),
      (true, ApprovalStatus.pending) => (
          Icons.check_circle_outline,
          'Nothing waiting',
          'Every card you sent has been reviewed.',
        ),
      (true, ApprovalStatus.rejected) => (
          Icons.thumb_up_outlined,
          'Nothing sent back',
          'The office has not returned any of your cards.',
        ),
      (true, ApprovalStatus.printed) => (
          Icons.print_disabled_outlined,
          'Nothing printed yet',
          'Approved cards appear here once they go through a print run.',
        ),
      _ => (
          Icons.filter_alt_off_outlined,
          'No submissions match',
          'Clear the search box or pick a different tab.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
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
