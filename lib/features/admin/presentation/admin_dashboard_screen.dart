import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
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
          _StatGrid(stats: stats),
          const SizedBox(height: 10),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Reports & Analytics',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Cross-school breakdown, approval rates, monthly trends & CSV exports'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/reports'),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(Icons.people_alt_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Operator & School Accounts',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Create school operator credentials and toggle active access'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/users'),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.secondary),
              title: const Text('Audit Log & Activity Trail',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Chronological history of approvals, rejections, exports & prints'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/audit'),
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
          label: 'Rejected',
          value: s.rejected,
          color: StatusColors.failed,
          icon: Icons.cancel_outlined,
        ),
        _StatTile(
          label: 'Ready to print',
          value: s.printable,
          color: const Color(0xFF4527A0),
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
