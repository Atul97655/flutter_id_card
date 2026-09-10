import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every card request, across every school, in one queue.
///
/// The per-school review screen still exists and is the right tool when working
/// through one school's batch. This is the other half the plan asks for: the
/// admin arriving in the morning wants "what is waiting for me?", not "which
/// school shall I open first?" - with a dozen schools the second question hides
/// the work.
class RequestsQueueScreen extends ConsumerStatefulWidget {
  const RequestsQueueScreen({super.key});

  static const String routePath = '/admin/requests';

  @override
  ConsumerState<RequestsQueueScreen> createState() =>
      _RequestsQueueScreenState();
}

class _RequestsQueueScreenState extends ConsumerState<RequestsQueueScreen> {
  final TextEditingController _search = TextEditingController();

  /// Defaults to Pending: the queue exists to clear a backlog, so it opens on
  /// the backlog rather than on everything ever submitted.
  ApprovalStatus? _status = ApprovalStatus.pending;
  String? _schoolId;
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StudentEntry> _filter(List<StudentEntry> all) {
    final String needle = _search.text.trim().toUpperCase();
    return all.where((StudentEntry e) {
      if (_status != null && e.approvalStatus != _status) return false;
      if (_schoolId != null && e.schoolId != _schoolId) return false;
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
        ref.watch(allEntriesProvider);
    final List<SchoolConfig> schools =
        ref.watch(allSchoolsProvider).value ?? const <SchoolConfig>[];

    final Map<String, String> schoolNames = <String, String>{
      for (final SchoolConfig s in schools) s.id: s.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card Requests'),
        actions: <Widget>[
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) =>
            Center(child: Text('Could not load requests: $e')),
        data: (List<StudentEntry> all) {
          final List<StudentEntry> filtered = _filter(all);

          return Column(
            children: <Widget>[
              _filterBar(all, schools),
              const Divider(height: 1),
              Expanded(
                child: SmoothSwitcher(
                  child: filtered.isEmpty
                      ? _Empty(
                          key: ValueKey<String>('empty-${_status?.name}'),
                          status: _status,
                        )
                      : ListView.separated(
                          key: ValueKey<String>(
                            '${_status?.name}-$_schoolId-${filtered.length}',
                          ),
                          padding: const EdgeInsets.all(AppTheme.gutter),
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext _, int _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final StudentEntry e = filtered[i];
                            return FadeSlideIn(
                              index: i,
                              child: _RequestTile(
                                entry: e,
                                schoolName: schoolNames[e.schoolId] ?? e.schoolId,
                                selected: _selected.contains(e.id),
                                selectionMode: _selected.isNotEmpty,
                                onToggle: () => setState(() {
                                  if (!_selected.remove(e.id)) {
                                    _selected.add(e.id);
                                  }
                                }),
                                onOpen: () => context.push(
                                  '/admin/schools/${e.schoolId}',
                                ),
                                onApprove: () => _approve(<String>[e.id]),
                                onReject: () => _rejectOne(e),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _selected.isEmpty ? null : _bulkBar(),
    );
  }

  Widget _filterBar(List<StudentEntry> all, List<SchoolConfig> schools) {
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
                for (final ApprovalStatus s in <ApprovalStatus>[
                  ApprovalStatus.pending,
                  ApprovalStatus.approved,
                  ApprovalStatus.printed,
                  ApprovalStatus.rejected,
                ])
                  _statusChip(
                    s,
                    s.label,
                    all.where((StudentEntry e) => e.approvalStatus == s).length,
                  ),
              ],
            ),
          ),
          if (schools.length > 1) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Icon(Icons.school_outlined, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _schoolId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        child: Text('All schools'),
                      ),
                      for (final SchoolConfig s in schools)
                        DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (String? v) => setState(() => _schoolId = v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(ApprovalStatus? status, String label, int count) {
    final bool selected = _status == status;
    final Color? tint =
        status == null ? null : ApprovalStatusChip.visualsFor(status).$1;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() {
          _status = selected ? null : status;
          // Selection is scoped to what is on screen; keeping ids across a
          // filter change would bulk-approve rows the admin can no longer see.
          _selected.clear();
        }),
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

  Widget _bulkBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 8, AppTheme.gutter, 8),
        child: Row(
          children: <Widget>[
            Text(
              '${_selected.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _rejectMany(_selected.toList()),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: StatusColors.failed,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _approve(_selected.toList()),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Approve'),
            ),
          ],
        ),
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
    await ref.read(auditRepositoryProvider).log(
          action: ids.length == 1 ? 'approve' : 'bulk_approve',
          entityType: 'student',
          entityId: ids.length == 1 ? ids.first : '${ids.length} entries',
          actorUid: uid,
          details: <String, Object?>{'ids': ids, 'from': 'requests_queue'},
        );

    if (!mounted) return;
    setState(_selected.clear);
    _say('${ids.length} approved');
  }

  Future<void> _rejectOne(StudentEntry entry) async {
    final String? reason = await _askReason(
      title: 'Send back ${entry.name}?',
    );
    if (reason == null) return;

    final String? uid = _reviewerUid;
    if (uid == null) return;

    await ref
        .read(studentRepositoryProvider)
        .reject(entry.id, reviewerUid: uid, reason: reason);
    await ref.read(auditRepositoryProvider).log(
          action: 'reject',
          entityType: 'student',
          entityId: entry.id,
          actorUid: uid,
          details: <String, Object?>{
            'reason': reason,
            'from': 'requests_queue',
          },
        );

    if (!mounted) return;
    _say('Sent back to ${entry.name.isEmpty ? 'the school' : entry.name}');
  }

  Future<void> _rejectMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final String? reason = await _askReason(
      title: 'Send back ${ids.length} cards?',
    );
    if (reason == null) return;

    final String? uid = _reviewerUid;
    if (uid == null) return;

    await ref
        .read(studentRepositoryProvider)
        .rejectAll(ids, reviewerUid: uid, reason: reason);
    await ref.read(auditRepositoryProvider).log(
          action: 'bulk_reject',
          entityType: 'student',
          entityId: '${ids.length} entries',
          actorUid: uid,
          details: <String, Object?>{
            'ids': ids,
            'reason': reason,
            'from': 'requests_queue',
          },
        );

    if (!mounted) return;
    setState(_selected.clear);
    _say('${ids.length} sent back');
  }

  /// A rejection without a reason is useless to the teacher receiving it, so
  /// the field is mandatory - the dialog cannot be confirmed while it is empty.
  Future<String?> _askReason({required String title}) async {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> form = GlobalKey<FormState>();

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'What does the school need to fix?',
            ),
            validator: (String? v) => (v ?? '').trim().isEmpty
                ? 'The school needs to know what to correct'
                : null,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StatusColors.failed,
            ),
            onPressed: () {
              if (!(form.currentState?.validate() ?? false)) return;
              Navigator.of(ctx).pop(controller.text.trim());
            },
            child: const Text('Send back'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.entry,
    required this.schoolName,
    required this.selected,
    required this.selectionMode,
    required this.onToggle,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  final StudentEntry entry;
  final String schoolName;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = entry.localPhotoPath;
    final bool hasThumb =
        path != null && path.isNotEmpty && File(path).existsSync();
    final bool actionable = entry.approvalStatus == ApprovalStatus.pending;

    return PressableSurface(
      // Long-press starts a selection; once selecting, a plain tap toggles.
      // That way a stray tap while clearing a backlog cannot navigate away.
      onTap: selectionMode ? onToggle : onOpen,
      onLongPress: onToggle,
      child: Card(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: selectionMode ? 34 : 0,
                    child: selectionMode
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => onToggle(),
                            visualDensity: VisualDensity.compact,
                          )
                        : const SizedBox.shrink(),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 55,
                      child: hasThumb
                          ? Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              cacheWidth: 150,
                              cacheHeight: 188,
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
                          schoolName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          <String>[
                            if (entry.studentClass.isNotEmpty)
                              'Class ${entry.studentClass}',
                            if (entry.division.isNotEmpty)
                              'Div ${entry.division}',
                            if (entry.rollNumber.isNotEmpty)
                              'Roll ${entry.rollNumber}',
                          ].join('  ·  '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            ApprovalStatusChip(
                              status: entry.approvalStatus,
                              dense: true,
                            ),
                            if (!entry.hasPhoto)
                              const _Warn(text: 'No photo'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionable && !selectionMode) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Send back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: StatusColors.failed,
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Warn extends StatelessWidget {
  const _Warn({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: StatusColors.pending.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StatusColors.pending.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: StatusColors.pending,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: StatusColors.pending,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.status});

  final ApprovalStatus? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool clearedBacklog = status == ApprovalStatus.pending;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              clearedBacklog ? Icons.done_all : Icons.filter_alt_off_outlined,
              size: 52,
              color: clearedBacklog
                  ? StatusColors.synced
                  : theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              clearedBacklog ? 'Queue is clear' : 'Nothing matches',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              clearedBacklog
                  ? 'No cards are waiting for review.'
                  : 'Try a different status, school or search.',
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
