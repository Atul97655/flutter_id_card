import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_id_card/shared/widgets/offline_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// ID Card Home - the operator's hub.
///
/// Rebuilt from a flat menu into a status surface. The menu answered "what can
/// I do?"; the question an operator actually arrives with is "where did my
/// cards get to?", and until now the app could not answer it at all - the
/// office's approval decision never reached this side.
///
/// Order is by urgency: anything sent back first, then the counts, then the
/// primary action, then recent work.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const String routePath = '/home';
  static const String routeName = 'home';

  /// How many recent submissions the hub shows before deferring to the full
  /// list. Five fits above the fold on a small tablet without scrolling.
  static const int _recentCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<SchoolConfig> config = ref.watch(schoolConfigProvider);
    final AsyncValue<Map<SyncStatus, int>> syncCounts =
        ref.watch(syncCountsProvider);
    final AsyncValue<Map<ApprovalStatus, int>> approvalCounts =
        ref.watch(submissionCountsProvider);
    final AsyncValue<List<StudentEntry>> entriesAsync =
        ref.watch(entriesProvider);
    final List<StudentEntry> rejected = ref.watch(needsAttentionProvider);

    final int unreadChats = ref.watch(unreadChatCountProvider);
    final int pending = syncCounts.value?[SyncStatus.pending] ?? 0;
    final int failed = syncCounts.value?[SyncStatus.failed] ?? 0;
    final List<StudentEntry> entries = entriesAsync.value ?? const <StudentEntry>[];
    final List<StudentEntry> recent = entries.take(_recentCount).toList();

    int count(ApprovalStatus s) => approvalCounts.value?[s] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID entity'),
        actions: <Widget>[
          if (session?.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin panel',
              onPressed: () => context.push('/admin'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.gutter),
                children: <Widget>[
                  FadeSlideIn(
                    child: _SchoolHeader(
                      config: config,
                      isOfflineTest: session?.isOfflineTestSession ?? false,
                    ),
                  ),

                  // Sent-back work is the only thing that is genuinely the
                  // operator's move, so it sits above everything else.
                  if (rejected.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppTheme.gutter),
                    FadeSlideIn(
                      index: 1,
                      child: _AttentionBanner(entries: rejected),
                    ),
                  ],

                  const SizedBox(height: AppTheme.gutter),
                  FadeSlideIn(
                    index: 2,
                    child: _StatusStrip(
                      pending: count(ApprovalStatus.pending),
                      approved: count(ApprovalStatus.approved),
                      printed: count(ApprovalStatus.printed),
                      onTap: () => context.push('/entries'),
                    ),
                  ),

                  const SizedBox(height: AppTheme.gutter),
                  const FadeSlideIn(index: 3, child: _NewCardButton()),

                  const SizedBox(height: AppTheme.gutter),
                  FadeSlideIn(
                    index: 4,
                    child: _RecentSubmissions(
                      recent: recent,
                      total: entries.length,
                    ),
                  ),

                  // Sync is plumbing. It earns a card only when something is
                  // stuck; a green "all synced" tile is pure noise.
                  if (pending > 0 || failed > 0) ...<Widget>[
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 5,
                      child: _MenuCard(
                        icon: Icons.sync_outlined,
                        title: 'Sync Status',
                        subtitle: _syncSubtitle(pending, failed),
                        color: failed > 0
                            ? StatusColors.failed
                            : const Color(0xFF4527A0),
                        badgeCount: pending + failed,
                        onTap: () => context.push('/sync'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 6,
                    child: _MenuCard(
                      icon: Icons.forum_outlined,
                      title: 'Messages',
                      subtitle: unreadChats == 0
                          ? 'Announcements and chat with the office'
                          : '$unreadChats conversation(s) with new messages',
                      badgeCount: unreadChats,
                      color: const Color(0xFFAD1457),
                      onTap: () => context.push('/messages'),
                    ),
                  ),

                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 7,
                    child: _MenuCard(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: session?.email ?? '',
                      color: const Color(0xFF546E7A),
                      onTap: () => _confirmLogout(context, ref),
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

  static String _syncSubtitle(int pending, int failed) {
    if (failed > 0) return '$failed failed, $pending waiting to upload';
    if (pending > 0) return '$pending waiting to upload';
    return 'Everything is up to date';
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final AsyncValue<Map<SyncStatus, int>> counts =
        ref.read(syncCountsProvider);
    final int unsynced = (counts.value?[SyncStatus.pending] ?? 0) +
        (counts.value?[SyncStatus.failed] ?? 0);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          unsynced > 0
              // Entries live in the local database, not in the session, so they
              // genuinely do survive - say so plainly to stop operators
              // hoarding logins out of fear of losing a day's work.
              ? '$unsynced entries have not uploaded yet.\n\nThey stay saved on '
                  'this device and will upload the next time you sign in.'
              : 'You will need your school code and password to sign back in.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

// ---------------------------------------------------------------------------
// Attention banner
// ---------------------------------------------------------------------------

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.entries});

  final List<StudentEntry> entries;

  @override
  Widget build(BuildContext context) {
    final bool single = entries.length == 1;

    return PressableSurface(
      onTap: () => single
          ? context.push('/submissions/${entries.first.id}')
          : context.push('/entries'),
      child: Card(
        color: StatusColors.failed.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
          side: BorderSide(color: StatusColors.failed.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.assignment_late_outlined,
                color: StatusColors.failed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      single
                          ? '1 card sent back'
                          : '${entries.length} cards sent back',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: StatusColors.failed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      single
                          ? entries.first.rejectionReason ??
                              'Open it to see why'
                          : 'Fix them and submit again',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: StatusColors.failed),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status strip
// ---------------------------------------------------------------------------

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.pending,
    required this.approved,
    required this.printed,
    required this.onTap,
  });

  final int pending;
  final int approved;
  final int printed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      scale: 0.985,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  status: ApprovalStatus.pending,
                  value: pending,
                  label: 'Waiting',
                ),
              ),
              const _StripDivider(),
              Expanded(
                child: _StatTile(
                  status: ApprovalStatus.approved,
                  value: approved,
                  label: 'Approved',
                ),
              ),
              const _StripDivider(),
              Expanded(
                child: _StatTile(
                  status: ApprovalStatus.printed,
                  value: printed,
                  label: 'Printed',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.status,
    required this.value,
    required this.label,
  });

  final ApprovalStatus status;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = ApprovalStatusChip.visualsFor(status);
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        AnimatedCount(
          value: value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: value == 0 ? theme.colorScheme.outline : color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Primary action
// ---------------------------------------------------------------------------

class _NewCardButton extends StatelessWidget {
  const _NewCardButton();

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: () => context.push('/entry/new'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF1A3D7C), Color(0xFF2E5FB0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF1A3D7C).withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'New ID Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Capture a photo and enter the details',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent submissions
// ---------------------------------------------------------------------------

class _RecentSubmissions extends StatelessWidget {
  const _RecentSubmissions({required this.recent, required this.total});

  final List<StudentEntry> recent;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Recent submissions',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (total > recent.length)
                  TextButton(
                    onPressed: () => context.push('/entries'),
                    child: Text('All $total'),
                  ),
              ],
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 8, 18),
                child: Text(
                  'Nothing submitted yet. Your cards and their status will '
                  'appear here.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final StudentEntry e in recent)
                _RecentRow(
                  entry: e,
                  onTap: () => context.push('/submissions/${e.id}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry, required this.onTap});

  final StudentEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = entry.localPhotoPath;
    final bool hasThumb =
        path != null && path.isNotEmpty && File(path).existsSync();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 30,
                height: 38,
                child: hasThumb
                    ? Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        cacheWidth: 100,
                        cacheHeight: 126,
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name.isEmpty ? 'UNNAMED' : entry.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.studentClass.isNotEmpty)
                    Text(
                      'Class ${entry.studentClass}'
                      '${entry.division.isEmpty ? '' : ' · Div ${entry.division}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ApprovalStatusChip(status: entry.approvalStatus, dense: true),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SchoolHeader extends StatelessWidget {
  const _SchoolHeader({required this.config, required this.isOfflineTest});

  final AsyncValue<SchoolConfig> config;
  final bool isOfflineTest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SchoolConfig? value = config.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.school,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value?.name ?? 'Loading...',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null
                        ? ''
                        : '${value.cardSize.label} - ${value.enabledFields.length} fields',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (isOfflineTest) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: const Text(
                        'OFFLINE TEST SESSION - will not sync',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PressableSurface(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
