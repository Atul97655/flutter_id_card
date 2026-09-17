import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/sync_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the operator whether their work has reached the server.
///
/// This screen is the answer to "did my data go through?", which is the single
/// most common support question for offline-first field apps. It reports counts
/// per status and lets a stuck queue be retried by hand.
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<SyncStatus, int>> counts = ref.watch(
      syncCountsProvider,
    );
    final AsyncValue<List<StudentEntry>> entries = ref.watch(entriesProvider);
    final bool backendUp = FirebaseBootstrap.instance.isReady;

    final List<StudentEntry> problems =
        (entries.value ?? const <StudentEntry>[])
            .where((StudentEntry e) => e.syncStatus == SyncStatus.failed)
            .toList();

    final List<StudentEntry> photosPending = ref.watch(
      photosAwaitingUploadProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Status')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          FadeSlideIn(child: _ConnectionBanner(backendUp: backendUp)),
          const SizedBox(height: AppTheme.gutter),
          SmoothSwitcher(
            child: photosPending.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.gutter),
                    child: _PhotosPendingCard(count: photosPending.length),
                  ),
          ),
          FadeSlideIn(
            index: 1,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.9,
              children: SyncStatus.values
                  .map(
                    (SyncStatus s) =>
                        _CountTile(status: s, count: counts.value?[s] ?? 0),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppTheme.gutter),
          if (problems.isNotEmpty) ...<Widget>[
            Text(
              'Failed uploads',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'These stay on the device until they upload. Nothing has been lost.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < problems.length; i++) ...<Widget>[
              FadeSlideIn(
                index: i + 2,
                child: _ProblemCard(entry: problems[i]),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _retryAll(context, ref),
              icon: const Icon(Icons.refresh),
              label: Text('Retry ${problems.length} failed uploads'),
            ),
          ] else
            const FadeSlideIn(index: 2, child: _AllClearCard()),
          const SizedBox(height: AppTheme.gutter),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'How syncing works',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Every entry is written to this device first, so you can work '
                    'all day with no signal. When a connection is available, '
                    'entries upload in the order they were created. Failed '
                    'uploads retry automatically.',
                    style: TextStyle(height: 1.45, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryAll(BuildContext context, WidgetRef ref) async {
    final String? schoolId = ref.read(activeSchoolIdProvider);
    if (schoolId == null) return;
    await ref.read(studentRepositoryProvider).resetFailures(schoolId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Queued for another attempt')));
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.backendUp});

  final bool backendUp;

  @override
  Widget build(BuildContext context) {
    final Color color = backendUp ? StatusColors.synced : StatusColors.pending;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(backendUp ? Icons.cloud_done : Icons.cloud_off, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              backendUp
                  ? 'Connected to the server'
                  : 'Server not configured - entries are saving locally only',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.status, required this.count});

  final SyncStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Color color = SyncStatusChip.colorFor(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(SyncStatusChip.iconFor(status), color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedCount(
                    value: count,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    status.label,
                    style: Theme.of(context).textTheme.bodySmall,
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

/// Photos the office does not have yet.
///
/// Deliberately separate from the failed-upload list. These records ARE at the
/// office and nothing needs re-entering - only the picture is outstanding, and
/// telling an operator "upload failed" for that sends them off to retake a
/// photo that was never the problem.
class _PhotosPendingCard extends StatelessWidget {
  const _PhotosPendingCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: StatusColors.pending.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
        side: BorderSide(color: StatusColors.pending.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.image_outlined,
              color: StatusColors.pending,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    count == 1
                        ? '1 photo still to send'
                        : '$count photos still to send',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: StatusColors.pending,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'The office already has these students. Only the picture '
                    'is outstanding, and it uploads by itself - keep the app '
                    'open on Wi-Fi for a minute. Do not retake the photo.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: theme.colorScheme.onSurfaceVariant,
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

/// One upload that has not made it, and why.
class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.entry});

  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(entry.name.isEmpty ? 'UNNAMED' : entry.name),
        subtitle: Text(
          entry.syncError ?? 'Unknown error',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${entry.syncAttempts} tries',
          style: const TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: StatusColors.synced,
            ),
            const SizedBox(height: 10),
            Text(
              'No failed uploads',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
