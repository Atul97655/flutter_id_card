import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/presentation/requests_queue_screen.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Admin landing screen: headline counts, then the school list.
///
/// Everything here reads from the local database, which the sync worker keeps
/// populated. That means the dashboard still renders on a flaky office
/// connection instead of showing a spinner over a dead network call.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  static const String routePath = '/admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminStats> stats = ref.watch(adminStatsProvider);
    final AsyncValue<List<SchoolConfig>> schools = ref.watch(allSchoolsProvider);
    final AsyncValue<List<StudentEntry>> entries = ref.watch(allEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reports & Analytics',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.push('/admin/reports'),
          ),
          IconButton(
            tooltip: 'Audit Log',
            icon: const Icon(Icons.history_edu_outlined),
            onPressed: () => context.push('/admin/audit'),
          ),
          IconButton(
            tooltip: 'User Management',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => context.push('/admin/users'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          // The backlog is why an admin opens this screen, so it leads -
          // above the stat grid, which is context rather than a task.
          if ((stats.value?.awaitingReview ?? 0) > 0) ...<Widget>[
            FadeSlideIn(
              child: _ReviewCallout(
                waiting: stats.value!.awaitingReview,
                onTap: () => context.push(RequestsQueueScreen.routePath),
              ),
            ),
            const SizedBox(height: AppTheme.gutter),
          ],

          FadeSlideIn(index: 1, child: _StatGrid(stats: stats)),
          const SizedBox(height: AppTheme.gutter),

          const FadeSlideIn(index: 2, child: _QuickActions()),
          const SizedBox(height: AppTheme.gutter),

          FadeSlideIn(
            index: 3,
            child: _LatestRequests(
              entries: entries.value ?? const <StudentEntry>[],
              schools: schools.value ?? const <SchoolConfig>[],
            ),
          ),

          const SizedBox(height: AppTheme.gutter * 1.5),
          Row(
            children: <Widget>[
              Text(
                'Schools',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/admin/schools/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add school'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          schools.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, StackTrace s) => _ErrorCard(message: '$e'),
            data: (List<SchoolConfig> list) => list.isEmpty
                ? const _NoSchoolsCard()
                : Column(
                    children: <Widget>[
                      for (final SchoolConfig school in list) ...<Widget>[
                        _SchoolCard(
                          school: school,
                          entries: (entries.value ?? const <StudentEntry>[])
                              .where((StudentEntry e) => e.schoolId == school.id)
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }
}

/// The one thing on this screen that is a task rather than information.
class _ReviewCallout extends StatelessWidget {
  const _ReviewCallout({required this.waiting, required this.onTap});

  final int waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFE8760A), Color(0xFFF5A623)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: StatusColors.pending.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.pending_actions,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      AnimatedCount(
                        value: waiting,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'awaiting review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Open the queue to approve or send them back',
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

/// Everything an admin does that is not reviewing a card.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
              child: Text(
                'Quick actions',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: <Widget>[
                _Action(
                  icon: Icons.fact_check_outlined,
                  label: 'Requests',
                  color: StatusColors.pending,
                  onTap: () => context.push(RequestsQueueScreen.routePath),
                ),
                _Action(
                  icon: Icons.campaign_outlined,
                  label: 'Bulk message',
                  color: const Color(0xFFAD1457),
                  onTap: () => context.push('/admin/broadcast'),
                ),
                _Action(
                  icon: Icons.forum_outlined,
                  label: 'Messages',
                  color: const Color(0xFF00695C),
                  onTap: () => context.push('/messages'),
                ),
                _Action(
                  icon: Icons.analytics_outlined,
                  label: 'Reports',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => context.push('/admin/reports'),
                ),
                _Action(
                  icon: Icons.people_alt_outlined,
                  label: 'Accounts',
                  color: const Color(0xFF4527A0),
                  onTap: () => context.push('/admin/users'),
                ),
                _Action(
                  icon: Icons.history_edu_outlined,
                  label: 'Audit log',
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => context.push('/admin/audit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The most recent submissions across every school.
class _LatestRequests extends StatelessWidget {
  const _LatestRequests({required this.entries, required this.schools});

  final List<StudentEntry> entries;
  final List<SchoolConfig> schools;

  static const int _max = 5;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, String> names = <String, String>{
      for (final SchoolConfig s in schools) s.id: s.name,
    };

    final List<StudentEntry> latest = <StudentEntry>[...entries]
      ..sort(
        (StudentEntry a, StudentEntry b) => b.createdAt.compareTo(a.createdAt),
      );
    final List<StudentEntry> shown = latest.take(_max).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Latest requests',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (entries.length > shown.length)
                  TextButton(
                    onPressed: () =>
                        context.push(RequestsQueueScreen.routePath),
                    child: const Text('See all'),
                  ),
              ],
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 12),
                child: Text(
                  'Nothing has been submitted yet.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final StudentEntry e in shown)
                InkWell(
                  onTap: () => context.push('/admin/schools/${e.schoolId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                e.name.isEmpty ? 'UNNAMED' : e.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                names[e.schoolId] ?? e.schoolId,
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
                        ApprovalStatusChip(
                          status: e.approvalStatus,
                          dense: true,
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.outline,
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final AsyncValue<AdminStats> stats;

  @override
  Widget build(BuildContext context) {
    final AdminStats s = stats.value ?? const AdminStats();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: <Widget>[
        _StatTile(
          label: 'Awaiting review',
          value: s.awaitingReview,
          color: StatusColors.pending,
          icon: Icons.pending_actions,
        ),
        _StatTile(
          label: 'Approved',
          value: s.approved,
          color: StatusColors.synced,
          icon: Icons.verified_outlined,
        ),
        _StatTile(
          label: 'Printed',
          value: s.printed,
          color: StatusColors.printed,
          icon: Icons.print_outlined,
        ),
        _StatTile(
          label: 'Ready to print',
          value: s.printable,
          color: const Color(0xFF00695C),
          icon: Icons.local_printshop_outlined,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school, required this.entries});

  final SchoolConfig school;
  final List<StudentEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int awaiting =
        entries.where((StudentEntry e) => e.approvalStatus.awaitsReview).length;

    return Card(
      child: InkWell(
        onTap: () => context.push('/admin/schools/${school.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(school.headerColorHex).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school, color: Color(school.headerColorHex)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      school.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entries.length} entries  -  ${school.cardSize.label}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (awaiting > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: StatusColors.pending,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$awaiting',
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

class _NoSchoolsCard extends StatelessWidget {
  const _NoSchoolsCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(Icons.school_outlined, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No schools yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Schools appear here once they exist in Firestore and have synced '
              'to this device. You can also add one directly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/admin/schools/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add the first school'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
