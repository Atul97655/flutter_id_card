import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/data/reports_service.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Comprehensive management reports dashboard: metrics, school breakdown, and monthly trends.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SystemReport> reportAsync = ref.watch(systemReportProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(systemReportProvider),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Failed to load reports: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.refresh(systemReportProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (SystemReport report) => ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: <Widget>[
            // ── Headline Metric Tiles ──────────────────────────────
            _HeadlineMetrics(report: report),
            const SizedBox(height: AppTheme.gutter * 1.5),

            // ── Monthly Submission Trends ──────────────────────────
            if (report.monthlyTrend.isNotEmpty) ...<Widget>[
              Text(
                'Monthly Submissions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _MonthlyTrendCard(items: report.monthlyTrend),
              const SizedBox(height: AppTheme.gutter * 1.5),
            ],

            // ── School Breakdown ───────────────────────────────────
            Row(
              children: <Widget>[
                Text(
                  'School Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${report.schoolReports.length} school(s)',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (report.schoolReports.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No schools configured yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              ...report.schoolReports.map(
                (SchoolReportItem s) => _SchoolReportCard(item: s),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeadlineMetrics extends StatelessWidget {
  const _HeadlineMetrics({required this.report});

  final SystemReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: <Widget>[
            _MetricTile(
              label: 'Total Students',
              value: '${report.totalStudents}',
              icon: Icons.badge_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            _MetricTile(
              label: 'Approved (${report.overallApprovalPercentage.toStringAsFixed(0)}%)',
              value: '${report.totalApproved}',
              icon: Icons.verified_outlined,
              color: StatusColors.synced,
            ),
            _MetricTile(
              label: 'Awaiting Review',
              value: '${report.totalPending}',
              icon: Icons.pending_actions,
              color: StatusColors.pending,
            ),
            _MetricTile(
              label: 'Total Cards Printed',
              value: '${report.totalCardsPrinted}',
              icon: Icons.print_outlined,
              color: const Color(0xFF673AB7),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
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

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.items});

  final List<MonthlySummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final int maxCount = items.fold<int>(0, (int m, MonthlySummaryItem i) => i.count > m ? i.count : m);
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final MonthlySummaryItem item in items) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 75,
                      child: Text(
                        item.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxCount > 0 ? (item.count / maxCount) : 0,
                          minHeight: 12,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 35,
                      child: Text(
                        '${item.count}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolReportCard extends StatelessWidget {
  const _SchoolReportCard({required this.item});

  final SchoolReportItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school_outlined, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.schoolName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        '${item.totalCount} total students · ${item.cardSizeLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Export CSV',
                  icon: const Icon(Icons.download_outlined, size: 20),
                  onPressed: () => context.push('/admin/export/${item.schoolId}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.totalCount > 0 ? (item.approvedCount / item.totalCount) : 0,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(StatusColors.synced),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _CountBadge(label: 'Approved', count: item.approvedCount, color: StatusColors.synced),
                _CountBadge(label: 'Pending', count: item.pendingCount, color: StatusColors.pending),
                _CountBadge(label: 'Rejected', count: item.rejectedCount, color: StatusColors.failed),
                _CountBadge(label: 'Printable', count: item.printableCount, color: theme.colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
