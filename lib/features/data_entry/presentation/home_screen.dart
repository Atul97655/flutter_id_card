import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Operator landing screen: five large targets, sized for gloved or hurried
/// taps on a cheap tablet.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const String routePath = '/home';
  static const String routeName = 'home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<SchoolConfig> config = ref.watch(schoolConfigProvider);
    final AsyncValue<Map<SyncStatus, int>> counts = ref.watch(syncCountsProvider);
    final AsyncValue<List<StudentEntry>> entries = ref.watch(entriesProvider);

    final int pending = counts.value?[SyncStatus.pending] ?? 0;
    final int failed = counts.value?[SyncStatus.failed] ?? 0;
    final int total = entries.value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card System'),
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
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: <Widget>[
            _SchoolHeader(
              config: config,
              isOfflineTest: session?.isOfflineTestSession ?? false,
            ),
            const SizedBox(height: AppTheme.gutter),
            _MenuCard(
              icon: Icons.badge_outlined,
              title: 'New ID Card',
              subtitle: 'Enter student details and capture a photo',
              color: const Color(0xFF1A3D7C),
              onTap: () => context.push('/entry/new'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.folder_open_outlined,
              title: 'Saved Entries',
              subtitle: total == 0 ? 'No entries yet' : '$total saved on this device',
              color: const Color(0xFF00695C),
              onTap: () => context.push('/entries'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.sync_outlined,
              title: 'Sync Status',
              subtitle: _syncSubtitle(pending, failed),
              color: failed > 0 ? StatusColors.failed : const Color(0xFF4527A0),
              badgeCount: pending + failed,
              onTap: () => context.push('/sync'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.forum_outlined,
              title: 'Messages',
              subtitle: 'Announcements and chat with the admin office',
              color: const Color(0xFFAD1457),
              onTap: () => context.push('/messages'),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: session?.email ?? '',
              color: const Color(0xFF546E7A),
              onTap: () => _confirmLogout(context, ref),
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
    final AsyncValue<Map<SyncStatus, int>> counts = ref.read(syncCountsProvider);
    final int unsynced =
        (counts.value?[SyncStatus.pending] ?? 0) + (counts.value?[SyncStatus.failed] ?? 0);

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
              child: Icon(Icons.school, color: theme.colorScheme.onPrimaryContainer),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

    return Card(
      child: InkWell(
        onTap: onTap,
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
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
