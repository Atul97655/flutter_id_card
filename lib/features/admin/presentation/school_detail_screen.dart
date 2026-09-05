import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/sync_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One school's submissions, with the review queue and bulk actions.
///
/// This is where the admin actually spends their time, so it is built around
/// the review loop: filter to what needs attention, look at the photo and the
/// details together, approve or send back with a reason.
class SchoolDetailScreen extends ConsumerStatefulWidget {
  const SchoolDetailScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  ConsumerState<SchoolDetailScreen> createState() => _SchoolDetailScreenState();
}

class _SchoolDetailScreenState extends ConsumerState<SchoolDetailScreen> {
  final TextEditingController _search = TextEditingController();

  ApprovalStatus? _statusFilter = ApprovalStatus.pending;
  String? _classFilter;
  String? _divFilter;

  /// Ids selected for a bulk action. Kept in the screen rather than a provider
  /// because a selection is transient UI state - navigating away should clear
  /// it, not resurrect a stale set of ids.
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StudentEntry> _applyFilters(List<StudentEntry> all) {
    final String needle = _search.text.trim().toUpperCase();
    return all.where((StudentEntry e) {
      if (_statusFilter != null && e.approvalStatus != _statusFilter) return false;
      if (_classFilter != null && e.studentClass != _classFilter) return false;
      if (_divFilter != null && e.division != _divFilter) return false;
      if (needle.isEmpty) return true;
      return e.name.contains(needle) ||
          e.studentClass.contains(needle) ||
          e.division.contains(needle) ||
          e.mobile.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SchoolConfig?> schoolAsync =
        ref.watch(schoolByIdProvider(widget.schoolId));
    final AsyncValue<List<StudentEntry>> entriesAsync =
        ref.watch(entriesForSchoolProvider(widget.schoolId));

    final SchoolConfig? school = schoolAsync.value;
    final List<StudentEntry> all = entriesAsync.value ?? const <StudentEntry>[];
    final List<StudentEntry> filtered = _applyFilters(all);

    return Scaffold(
      appBar: AppBar(
        title: Text(school?.name ?? 'School'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Print & export',
            icon: const Icon(Icons.local_printshop_outlined),
            onPressed: () => context.push('/admin/schools/${widget.schoolId}/print'),
          ),
          IconButton(
            tooltip: 'School settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                context.push('/admin/schools/${widget.schoolId}/settings'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _filterBar(all),
          const Divider(height: 1),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace s) => Center(child: Text('$e')),
              data: (_) => filtered.isEmpty
                  ? _EmptyState(hasAny: all.isNotEmpty, filter: _statusFilter)
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.gutter),
                      itemCount: filtered.length,
                      separatorBuilder: (BuildContext _, int _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int i) {
                        final StudentEntry entry = filtered[i];
                        return _SubmissionTile(
                          entry: entry,
                          selected: _selected.contains(entry.id),
                          onSelectedChanged: (bool v) => setState(() {
                            if (v) {
                              _selected.add(entry.id);
                            } else {
                              _selected.remove(entry.id);
                            }
                          }),
                          onApprove: () => _approve(<String>[entry.id]),
                          onReject: () => _promptReject(entry),
                          onPreview: () => context.push('/preview/${entry.id}'),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty ? null : _bulkBar(filtered),
    );
  }

  Widget _filterBar(List<StudentEntry> all) {
    final List<String> classes = all
        .map((StudentEntry e) => e.studentClass)
        .where((String c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final List<String> divisions = all
        .map((StudentEntry e) => e.division)
        .where((String d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

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
                for (final ApprovalStatus s in ApprovalStatus.values)
                  _statusChip(
                    s,
                    s.label,
                    all.where((StudentEntry e) => e.approvalStatus == s).length,
                  ),
                if (classes.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 6),
                  _dropdownChip(
                    label: 'Class',
                    value: _classFilter,
                    options: classes,
                    onChanged: (String? v) => setState(() => _classFilter = v),
                  ),
                ],
                if (divisions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 6),
                  _dropdownChip(
                    label: 'Div',
                    value: _divFilter,
                    options: divisions,
                    onChanged: (String? v) => setState(() => _divFilter = v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ApprovalStatus? status, String label, int count) {
    final bool selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() {
          _statusFilter = selected ? null : status;
          _selected.clear();
        }),
        showCheckmark: false,
      ),
    );
  }

  Widget _dropdownChip({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
        const PopupMenuItem<String?>(child: Text('All')),
        for (final String o in options)
          PopupMenuItem<String?>(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(value == null ? label : '$label: $value'),
        avatar: const Icon(Icons.filter_list, size: 16),
      ),
    );
  }

  Widget _bulkBar(List<StudentEntry> visible) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(AppTheme.gutter, 0, AppTheme.gutter, 12),
      child: Row(
        children: <Widget>[
          Text('${_selected.length} selected'),
          const Spacer(),
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _approve(_selected.toList()),
            icon: const Icon(Icons.check),
            label: Text('Approve ${_selected.length}'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Review actions
  // ------------------------------------------------------------------

  String? get _reviewerUid => ref.read(currentSessionProvider)?.uid;

  Future<void> _approve(List<String> ids) async {
    final String? uid = _reviewerUid;
    if (uid == null || ids.isEmpty) return;

    await ref.read(studentRepositoryProvider).approveAll(ids, reviewerUid: uid);
    if (!mounted) return;

    setState(_selected.clear);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1 ? 'Approved' : 'Approved ${ids.length} entries',
          ),
        ),
      );
  }

  Future<void> _promptReject(StudentEntry entry) async {
    final TextEditingController reason = TextEditingController();

    final String? given = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Reject ${entry.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'The operator sees this reason, so be specific about what to fix.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              autofocus: true,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Photo is blurred - retake in better light',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StatusColors.failed),
            onPressed: () {
              final String text = reason.text.trim();
              // A rejection with no reason just bounces the entry back and
              // forth, so the button stays inert until one is given.
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    reason.dispose();

    final String? uid = _reviewerUid;
    if (given == null || uid == null) return;

    await ref
        .read(studentRepositoryProvider)
        .reject(entry.id, reviewerUid: uid, reason: given);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Rejected ${entry.name}')));
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({
    required this.entry,
    required this.selected,
    required this.onSelectedChanged,
    required this.onApprove,
    required this.onReject,
    required this.onPreview,
  });

  final StudentEntry entry;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = entry.localPhotoPath;
    final bool hasThumb = path != null && path.isNotEmpty && File(path).existsSync();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  value: selected,
                  onChanged: (bool? v) => onSelectedChanged(v ?? false),
                ),
                GestureDetector(
                  onTap: onPreview,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 60,
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
                          if (entry.mobile.isNotEmpty) entry.mobile,
                        ].join('  -  '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          _ApprovalChip(status: entry.approvalStatus),
                          SyncStatusChip(status: entry.syncStatus, dense: true),
                          if (!entry.hasPhoto)
                            const _WarningChip(text: 'No photo'),
                        ],
                      ),
                      if (entry.rejectionReason != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Reason: ${entry.rejectionReason}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: StatusColors.failed,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview'),
                ),
                const SizedBox(width: 4),
                if (entry.approvalStatus != ApprovalStatus.rejected)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: StatusColors.failed,
                    ),
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                const SizedBox(width: 4),
                if (entry.approvalStatus != ApprovalStatus.approved)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  const _ApprovalChip({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (status) {
      ApprovalStatus.pending => (StatusColors.pending, Icons.pending_actions),
      ApprovalStatus.approved => (StatusColors.synced, Icons.verified),
      ApprovalStatus.rejected => (StatusColors.failed, Icons.cancel_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: StatusColors.failed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StatusColors.failed.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: StatusColors.failed,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny, required this.filter});

  final bool hasAny;
  final ApprovalStatus? filter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String title;
    final String detail;
    if (!hasAny) {
      title = 'No submissions yet';
      detail = 'Entries appear here once an operator submits them and they sync.';
    } else if (filter == ApprovalStatus.pending) {
      title = 'Review queue is clear';
      detail = 'Nothing is waiting on you. Switch the filter to see other entries.';
    } else {
      title = 'Nothing matches this filter';
      detail = 'Try a different status, class or division.';
    }

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
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              detail,
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
