import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/features/notifications/domain/app_notification.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Everything that happened to this operator's work, newest first.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppNotification> items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.all(AppTheme.gutter),
              itemCount: items.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int i) => FadeSlideIn(
                index: i,
                child: _NotificationTile(item: items[i]),
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _day = DateFormat('dd MMM');

  /// Relative for anything recent, absolute once it stops being "today" -
  /// "3 days ago" is harder to act on than a date.
  static String _when(DateTime at) {
    final Duration ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'Just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
    if (ago.inHours < 24) return _time.format(at);
    if (ago.inDays == 1) return 'Yesterday';
    return _day.format(at);
  }

  static (Color, IconData) _visuals(NotificationKind kind) => switch (kind) {
        NotificationKind.cardApproved => (
            StatusColors.synced,
            Icons.verified_outlined,
          ),
        NotificationKind.cardRejected => (
            StatusColors.failed,
            Icons.assignment_late_outlined,
          ),
        NotificationKind.cardPrinted => (
            StatusColors.printed,
            Icons.print_outlined,
          ),
        NotificationKind.newMessage => (
            const Color(0xFFAD1457),
            Icons.forum_outlined,
          ),
        NotificationKind.broadcast => (
            const Color(0xFF00695C),
            Icons.campaign_outlined,
          ),
        NotificationKind.syncFailed => (
            StatusColors.failed,
            Icons.cloud_off_outlined,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color color, IconData icon) = _visuals(item.kind);

    return PressableSurface(
      onTap: item.route == null ? null : () => context.push(item.route!),
      child: Card(
        color: item.unread ? color.withValues(alpha: 0.06) : null,
        shape: item.unread
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _when(item.at),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (item.route != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

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
              Icons.notifications_none,
              size: 52,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text('Nothing new', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Approvals, returned cards and messages from the office will '
              'show up here.',
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
