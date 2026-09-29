import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/features/onboarding/application/join_providers.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/entry_photo.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_id_card/shared/widgets/offline_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The operator's home: what this school is, what has happened, and the one
/// button that starts the job.
///
/// Redesigned against the reference pack. Every provider read, route and
/// conditional below is the same as before - only the arrangement moved.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const String routePath = '/home';
  static const String routeName = 'home';

  /// How many recent submissions the card shows before deferring to the full
  /// list. Four fills the card without turning the home screen into a second
  /// copy of My Submissions.
  static const int _recentCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<SchoolConfig> config = ref.watch(schoolConfigProvider);
    final AsyncValue<Map<SyncStatus, int>> syncCounts = ref.watch(
      syncCountsProvider,
    );
    final AsyncValue<Map<ApprovalStatus, int>> approvalCounts = ref.watch(
      submissionCountsProvider,
    );
    final AsyncValue<List<StudentEntry>> entriesAsync = ref.watch(
      entriesProvider,
    );
    final int unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final String section = ref.watch(mySectionLabelProvider);

    final int pending = syncCounts.value?[SyncStatus.pending] ?? 0;
    final int failed = syncCounts.value?[SyncStatus.failed] ?? 0;
    final List<StudentEntry> entries =
        entriesAsync.value ?? const <StudentEntry>[];
    final List<StudentEntry> recent = entries.take(_recentCount).toList();

    int count(ApprovalStatus s) => approvalCounts.value?[s] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.pageBlue),
        child: Column(
          children: <Widget>[
            _Header(
              section: section,
              unread: unreadNotifications,
              isAdmin: session?.isAdmin ?? false,
            ),
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  AppSpacing.navClearance,
                ),
                children: <Widget>[
                  FadeSlideIn(
                    child: _SchoolCard(
                      config: config,
                      isOfflineTest: session?.isOfflineTestSession ?? false,
                    ),
                  ),

                  // A returned card used to raise a red banner here. It was
                  // permanent: nothing on this screen could dismiss it and it
                  // reappeared on every launch until the card was resubmitted,
                  // so the first thing the operator saw every morning was an
                  // alarm they had already read. Returned cards now live in
                  // the notifications panel, where they can be seen and
                  // cleared, and stay visible in the list below as a status
                  // chip - which is where an operator looks for their own work
                  // anyway.
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(
                    index: 2,
                    child: _StatsCard(
                      waiting: count(ApprovalStatus.pending),
                      approved: count(ApprovalStatus.approved),
                      printed: count(ApprovalStatus.printed),
                      onTap: () => context.push('/entries'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  const FadeSlideIn(index: 3, child: _NewCardCta()),

                  const SizedBox(height: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      index: 5,
                      child: _SyncCard(
                        pending: pending,
                        failed: failed,
                        onTap: () => context.push('/sync'),
                      ),
                    ),
                  ],

                  // Messages and Logout used to live here as menu rows. They
                  // are now the Chats and Profile tabs - repeating them would
                  // give the same action two homes.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The navy block at the top of the page.
///
/// Curved along its bottom edge so the light page appears to slide under it.
/// A square edge here reads as two screens stacked; the curve is what makes
/// it one surface.
class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.unread,
    required this.isAdmin,
  });

  final String section;
  final int unread;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.header,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('ID entity', style: AppTypography.displayOnDark),
                    const SizedBox(height: 3),
                    Text(
                      'Manage school ID cards with ease',
                      style: AppTypography.displaySubOnDark,
                    ),
                    // The scope, stated. A teacher who cannot see a student
                    // they know exists needs to be told they are looking at
                    // one section, not left to conclude the card was lost.
                    if (section.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      GlassStatusBadge(
                        label: 'Class $section',
                        color: AppColors.onDark,
                        tint: const Color(0x2EFFFFFF),
                        icon: Icons.group_outlined,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GlassIconButton(
                icon: Icons.notifications_none_rounded,
                onDark: true,
                badge: unread > 0,
                tooltip: unread == 0
                    ? 'Notifications'
                    : '$unread need your attention',
                onTap: () => context.push('/notifications'),
              ),
              if (isAdmin) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                GlassIconButton(
                  icon: Icons.admin_panel_settings_outlined,
                  onDark: true,
                  tooltip: 'Admin panel',
                  onTap: () => context.push('/admin'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.config, required this.isOfflineTest});

  final AsyncValue<SchoolConfig> config;
  final bool isOfflineTest;

  @override
  Widget build(BuildContext context) {
    final SchoolConfig? value = config.value;

    return GlassSurface(
      fill: AppColors.card,
      borderColor: AppColors.hairline,
      sheen: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          const GlassIconTile(icon: Icons.school_rounded, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value?.name ?? 'Loading…',
                  style: AppTypography.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value == null
                      ? ''
                      : '${value.cardSize.label}  ·  ${value.enabledFields.length} fields',
                  style: AppTypography.support,
                ),
                if (isOfflineTest) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const GlassStatusBadge(
                    label: 'OFFLINE TEST — will not sync',
                    color: AppColors.pending,
                    tint: AppColors.pendingTint,
                    icon: Icons.wifi_off_rounded,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.waiting,
    required this.approved,
    required this.printed,
    required this.onTap,
  });

  final int waiting;
  final int approved;
  final int printed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      fill: AppColors.card,
      borderColor: AppColors.hairline,
      sheen: false,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GlassStat(
              icon: Icons.schedule_rounded,
              value: '$waiting',
              label: 'Waiting',
              tint: AppColors.pending,
            ),
          ),
          const _SoftDivider(),
          Expanded(
            child: GlassStat(
              icon: Icons.check_circle_outline_rounded,
              value: '$approved',
              label: 'Approved',
              tint: AppColors.approved,
            ),
          ),
          const _SoftDivider(),
          Expanded(
            child: GlassStat(
              icon: Icons.print_outlined,
              value: '$printed',
              label: 'Printed',
              tint: AppColors.printed,
            ),
          ),
        ],
      ),
    );
  }
}

/// A divider that fades out at both ends.
///
/// The brief asks for the three statistics to be separated without harsh
/// lines. A full-height rule between them is exactly the harsh line it means;
/// this states the same boundary and then gets out of the way.
class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x0016346E),
            Color(0x1A16346E),
            Color(0x0016346E),
          ],
        ),
      ),
    );
  }
}

/// The primary action on the screen, and it looks like it.
class _NewCardCta extends StatelessWidget {
  const _NewCardCta();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      fill: Colors.transparent,
      borderColor: const Color(0x2EFFFFFF),
      shadows: AppShadows.lifted,
      sheen: false,
      onTap: () => context.push('/entry/new'),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.actionDark),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              const GlassIconTile(
                icon: Icons.add_a_photo_outlined,
                tint: AppColors.onDark,
                background: Color(0x24FFFFFF),
                size: 52,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'New ID Card',
                      style: AppTypography.displayOnDark.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Capture a photo and enter the details',
                      style: AppTypography.supportOnDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0x2EFFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: AppColors.onDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSubmissions extends StatelessWidget {
  const _RecentSubmissions({required this.recent, required this.total});

  final List<StudentEntry> recent;
  final int total;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      fill: AppColors.card,
      borderColor: AppColors.hairline,
      sheen: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const GlassIconTile(icon: Icons.history_rounded, size: 34),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text('Recent submissions', style: AppTypography.section),
              ),
              if (total > 0)
                TextButton(
                  onPressed: () => context.push('/entries'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'View all',
                        style: AppTypography.support.copyWith(
                          color: AppColors.royal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: AppColors.royal,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.lg),
              child: Text(
                'Nothing submitted yet. Tap New ID Card to start.',
                style: AppTypography.support,
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
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry, required this.onTap});

  final StudentEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.fieldR,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            EntryPhoto(entry: entry),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                entry.name.isEmpty ? 'Unnamed' : entry.name,
                style: AppTypography.section.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusPill(status: entry.approvalStatus),
            const Icon(
              Icons.chevron_right,
              size: 19,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color tint, IconData icon) = switch (status) {
      ApprovalStatus.approved => (
        AppColors.approved,
        AppColors.approvedTint,
        Icons.check_circle,
      ),
      ApprovalStatus.rejected => (
        AppColors.rejected,
        AppColors.rejectedTint,
        Icons.cancel,
      ),
      ApprovalStatus.printed => (
        AppColors.printed,
        AppColors.printedTint,
        Icons.print,
      ),
      ApprovalStatus.pending => (
        AppColors.pending,
        AppColors.pendingTint,
        Icons.schedule,
      ),
    };

    return GlassStatusBadge(
      label: switch (status) {
        ApprovalStatus.approved => 'Approved',
        ApprovalStatus.rejected => 'Rejected',
        ApprovalStatus.printed => 'Printed',
        ApprovalStatus.pending => 'Pending',
      },
      color: color,
      tint: tint,
      icon: icon,
      compact: true,
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.pending,
    required this.failed,
    required this.onTap,
  });

  final int pending;
  final int failed;
  final VoidCallback onTap;

  String get _subtitle {
    if (failed > 0) return '$failed failed, $pending waiting to upload';
    if (pending > 0) return '$pending waiting to upload';
    return 'Everything is up to date';
  }

  @override
  Widget build(BuildContext context) {
    final bool bad = failed > 0;

    return GlassSurface(
      fill: AppColors.card,
      borderColor: AppColors.hairline,
      sheen: false,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: GlassListRow(
        icon: Icons.sync_rounded,
        title: 'Sync status',
        subtitle: _subtitle,
        tint: bad ? AppColors.rejected : AppColors.printed,
        onTap: onTap,
      ),
    );
  }
}
