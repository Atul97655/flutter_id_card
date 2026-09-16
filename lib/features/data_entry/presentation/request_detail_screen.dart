import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One submission, from the teacher's side.
///
/// This screen exists because the review decision was previously invisible to
/// the person who made the submission - the admin's approval and rejection
/// reason lived only on the admin's screens. A teacher whose card was sent back
/// had no way to find out why except by ringing the office, which is exactly
/// what the messaging feature is supposed to replace.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.entryId});

  final String entryId;

  static final DateFormat _stamp = DateFormat('dd MMM yyyy, h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StudentEntry? entry = ref.watch(entryByIdProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission'),
        actions: <Widget>[
          if (entry != null)
            IconButton(
              tooltip: 'Preview card',
              icon: const Icon(Icons.badge_outlined),
              onPressed: () => context.push('/preview/${entry.id}'),
            ),
        ],
      ),
      body: entry == null
          ? const _MissingEntry()
          : ListView(
              padding: const EdgeInsets.all(AppTheme.gutter),
              children: <Widget>[
                FadeSlideIn(child: _HeaderCard(entry: entry)),
                const SizedBox(height: AppTheme.gutter),

                // The remark comes before the timeline: when a card is sent
                // back, "why" is the only thing the teacher opened this screen
                // to read.
                if (entry.rejectionReason != null) ...<Widget>[
                  FadeSlideIn(index: 1, child: _RemarkCard(entry: entry)),
                  const SizedBox(height: AppTheme.gutter),
                ],

                FadeSlideIn(
                  index: entry.rejectionReason == null ? 1 : 2,
                  child: _TimelineCard(entry: entry, stamp: _stamp),
                ),
                const SizedBox(height: AppTheme.gutter),

                FadeSlideIn(
                  index: entry.rejectionReason == null ? 2 : 3,
                  child: _DetailsCard(entry: entry),
                ),
                const SizedBox(height: AppTheme.gutter),

                FadeSlideIn(
                  index: entry.rejectionReason == null ? 3 : 4,
                  child: _ActionsCard(entry: entry),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header - photo, name, status
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.entry});

  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = entry.localPhotoPath;
    final bool hasThumb =
        path != null && path.isNotEmpty && File(path).existsSync();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Hero(
              // Shares the thumbnail with the list row it was tapped from, so
              // the photo appears to grow into place rather than the whole
              // screen cross-fading.
              tag: 'entry-photo-${entry.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 90, // 1.2 x 1.5 in, the card's photo ratio
                  child: hasThumb
                      ? Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          cacheWidth: 240,
                          cacheHeight: 300,
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_outline,
                            color: theme.colorScheme.outline,
                            size: 32,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name.isEmpty ? 'UNNAMED' : entry.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
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
                  ),
                  const SizedBox(height: 10),
                  ApprovalStatusChip(status: entry.approvalStatus),
                  const SizedBox(height: 10),
                  _RequestIdRow(entry: entry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The short request id the teacher quotes to the office.
///
/// The full UUID is unreadable over a phone call, so only the first segment is
/// shown - it is short enough to say aloud and still unique within a school's
/// working set.
class _RequestIdRow extends StatelessWidget {
  const _RequestIdRow({required this.entry});

  final StudentEntry entry;

  static String shortId(String id) {
    final String cleaned = id.replaceAll('-', '').toUpperCase();
    return cleaned.length <= 6 ? cleaned : cleaned.substring(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(
          Icons.tag,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        SelectableText(
          shortId(entry.id),
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Admin remark
// ---------------------------------------------------------------------------

class _RemarkCard extends StatelessWidget {
  const _RemarkCard({required this.entry});

  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: StatusColors.failed.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.feedback_outlined,
                  size: 18,
                  color: StatusColors.failed,
                ),
                SizedBox(width: 8),
                Text(
                  'Sent back by the office',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: StatusColors.failed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.rejectionReason!,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              'Fix the point above and submit again. The card stays in your '
              'list until it is approved.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status timeline
// ---------------------------------------------------------------------------

/// One row of the progress timeline.
enum _StepState { done, active, blocked, waiting }

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry, required this.stamp});

  final StudentEntry entry;
  final DateFormat stamp;

  /// Builds the four-step journey a submission takes.
  ///
  /// Rejection is modelled as a *blocked* review step rather than a fifth step,
  /// because the card has not moved on - it is sitting at review waiting for
  /// the teacher, and drawing it as progress would be a lie.
  List<_Step> _steps() {
    final bool uploaded = entry.syncStatus == SyncStatus.synced;

    // "The details reached the office" is a different question to "did the
    // whole row succeed". A missing photo fails the row while the submission
    // itself is safely on the server, and calling that "Upload failed" sent
    // operators back to re-shoot photos that were never the problem.
    final bool detailsUp = entry.detailsReachedServer;
    final bool photoPending = entry.awaitingPhotoUpload;
    final bool failed = entry.syncStatus == SyncStatus.failed && !detailsUp;
    final ApprovalStatus status = entry.approvalStatus;
    final bool reviewed = status != ApprovalStatus.pending;
    final bool rejected = status == ApprovalStatus.rejected;
    final bool printed = status == ApprovalStatus.printed;

    return <_Step>[
      _Step(
        icon: Icons.edit_note,
        title: 'Submitted',
        subtitle: stamp.format(entry.createdAt),
        state: _StepState.done,
      ),
      _Step(
        icon: failed
            ? Icons.cloud_off
            : (photoPending
                ? Icons.cloud_sync_outlined
                : Icons.cloud_done_outlined),
        title: failed
            ? 'Upload failed'
            : (photoPending
                ? 'Details received, photo still uploading'
                : 'Uploaded to the office'),
        subtitle: failed
            ? (entry.syncError ?? 'Will retry automatically when back online')
            : (photoPending
                ? 'The office already has this card. The photo uploads by '
                    'itself - there is nothing to redo.'
                : switch (entry.syncStatus) {
                    SyncStatus.synced => 'Received',
                    SyncStatus.failed => 'Received',
                    SyncStatus.syncing => 'Uploading now...',
                    SyncStatus.pending => 'Waiting for a connection',
                  }),
        // Photo-pending is deliberately `active`, not `blocked`: nothing is
        // wrong and nothing is required of the operator.
        state: uploaded
            ? _StepState.done
            : failed
                ? _StepState.blocked
                : (detailsUp || photoPending
                    ? _StepState.active
                    : _StepState.active),
      ),
      _Step(
        icon: rejected ? Icons.cancel_outlined : Icons.verified_outlined,
        title: rejected ? 'Sent back' : 'Reviewed by the office',
        subtitle: switch (status) {
          ApprovalStatus.pending => (uploaded || detailsUp)
              ? 'Waiting for review'
              : 'Starts once it uploads',
          ApprovalStatus.rejected => entry.reviewedAt == null
              ? 'See the reason above'
              : stamp.format(entry.reviewedAt!),
          _ => entry.reviewedAt == null
              ? 'Approved'
              : 'Approved ${stamp.format(entry.reviewedAt!)}',
        },
        state: rejected
            ? _StepState.blocked
            : (reviewed
                ? _StepState.done
                : ((uploaded || detailsUp)
                    ? _StepState.active
                    : _StepState.waiting)),
      ),
      _Step(
        icon: Icons.print_outlined,
        title: 'Printed',
        subtitle: printed
            ? 'The card has been printed'
            : (rejected
                ? 'Blocked until the card is approved'
                : 'Waiting for the next print run'),
        state: printed
            ? _StepState.done
            : (status == ApprovalStatus.approved
                ? _StepState.active
                : _StepState.waiting),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<_Step> steps = _steps();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Progress',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < steps.length; i++)
              _TimelineRow(
                step: steps[i],
                isLast: i == steps.length - 1,
                index: i,
              ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _StepState state;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.index,
  });

  final _Step step;
  final bool isLast;
  final int index;

  Color _color(BuildContext context) => switch (step.state) {
        _StepState.done => StatusColors.synced,
        _StepState.active => StatusColors.syncing,
        _StepState.blocked => StatusColors.failed,
        _StepState.waiting => Theme.of(context).colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _color(context);
    final bool dim = step.state == _StepState.waiting;

    return FadeSlideIn(
      index: index,
      offset: 8,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              children: <Widget>[
                const SizedBox(height: 10),
                _StepDot(
                  icon: step.icon,
                  color: color,
                  filled: step.state != _StepState.waiting,
                  pulsing: step.state == _StepState.active,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: step.state == _StepState.done
                          ? StatusColors.synced.withValues(alpha: 0.35)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 10, bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      step.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dim ? theme.colorScheme.outline : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dim
                            ? theme.colorScheme.outline
                            : theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dot on the timeline rail. The active step breathes so the eye lands on
/// "where is my card right now" without reading every row.
class _StepDot extends StatefulWidget {
  const _StepDot({
    required this.icon,
    required this.color,
    required this.filled,
    required this.pulsing,
  });

  final IconData icon;
  final Color color;
  final bool filled;
  final bool pulsing;

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  /// Cycles the dot breathes before settling.
  ///
  /// Deliberately finite rather than `repeat()`. Three cycles is enough to pull
  /// the eye to the live step when the screen opens, and an animation that
  /// never stops would keep a cheap tablet rendering frames for as long as the
  /// screen is open - the same reason the rest of the app caps its motion.
  static const int _cycles = 3;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _pulse.addStatusListener(_onCycle);
    if (widget.pulsing) _pulse.forward();
  }

  /// Bounces the controller forward/back until [_cycles] round trips are done,
  /// then leaves it at rest.
  void _onCycle(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _pulse.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _completed++;
      if (_completed < _cycles && widget.pulsing) _pulse.forward();
    }
  }

  @override
  void didUpdateWidget(_StepDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !old.pulsing) {
      _completed = 0;
      _pulse.forward();
    } else if (!widget.pulsing && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.removeStatusListener(_onCycle);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget dot = AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.decelerate,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.filled
            ? widget.color.withValues(alpha: 0.14)
            : Colors.transparent,
        border: Border.all(
          color: widget.filled
              ? widget.color
              : Theme.of(context).colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Icon(widget.icon, size: 15, color: widget.color),
    );

    if (!widget.pulsing) return dot;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        // A very shallow pulse - anything larger jitters the rail beside it.
        scale: 1 + (_pulse.value * 0.06),
        child: child,
      ),
      child: dot,
    );
  }
}

// ---------------------------------------------------------------------------
// Details
// ---------------------------------------------------------------------------

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.entry});

  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<(String, String)> rows = <(String, String)>[
      for (final StudentField f in StudentField.printableRows)
        if (entry.valueOf(f).trim().isNotEmpty) (f.formLabel, entry.valueOf(f)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Details submitted',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final (String label, String value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 104,
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({required this.entry});

  final StudentEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Chat? adminChat = ref.watch(adminChatProvider);

    // An approved or printed card is a finished record. Letting it be edited
    // would silently invalidate a card that may already be in a school's hands,
    // so editing stops at the review boundary.
    final bool editable = !entry.approvalStatus.isApproved;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (editable)
              FilledButton.icon(
                onPressed: () => context.push('/entry/${entry.id}'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  entry.approvalStatus == ApprovalStatus.rejected
                      ? 'Fix and resubmit'
                      : 'Edit details',
                ),
              )
            else
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: StatusColors.synced,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Approved cards are locked. Message the office if '
                      'something needs to change.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: adminChat == null
                  ? null
                  : () => context.push('/messages/${adminChat.id}'),
              icon: const Icon(Icons.forum_outlined),
              label: Text(
                adminChat == null
                    ? 'The office has not opened a chat yet'
                    : 'Message the office',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingEntry extends StatelessWidget {
  const _MissingEntry();

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
              Icons.search_off,
              size: 52,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text('Submission not found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'It may have been deleted from this device.',
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
