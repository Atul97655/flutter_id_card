import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/features/notifications/domain/app_notification.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/local/app_flag_repository.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Everything that happened to this operator's work, newest first.
///
/// Opening this screen is what clears the badge. The feed has no rows of its
/// own to mark read - it is derived from entry statuses, chats and sync state -
/// so "seen" is recorded as one timestamp, and anything older stops counting.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// The watermark as it was when this screen opened.
  ///
  /// Kept so the list still shows what was new *on arrival*. Stamping the new
  /// watermark and then reading it back would turn every row read under the
  /// operator's eyes in the first frame, hiding the very thing they came for.
  DateTime? _openedWith;
  bool _stamped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
  }

  Future<void> _markSeen() async {
    final AppFlagRepository flags = ref.read(appFlagRepositoryProvider);
    final DateTime? previous = await flags.readDateTime(
      AppFlagRepository.notificationsSeenAtKey,
    );
    if (!mounted) return;
    setState(() {
      _openedWith = previous;
      _stamped = true;
    });
    await flags.markNotificationsSeen();
  }

  /// Before the stamp lands the provider's own answer is still the pre-open
  /// one and is correct. Afterwards the provider says everything is read, so
  /// the snapshot above takes over.
  bool _isNew(AppNotification n) {
    if (!_stamped) return n.unread;
    return _openedWith == null || n.at.isAfter(_openedWith!);
  }

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SmoothSwitcher(
        child: items.isEmpty
            ? const _Empty()
            : ListView.separated(
                key: ValueKey<int>(items.length),
                padding: const EdgeInsets.all(AppTheme.gutter),
                itemCount: items.length,
                separatorBuilder: (BuildContext _, int _) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int i) => FadeSlideIn(
                  index: i,
                  child: _NotificationTile(
                    item: items[i],
                    isNew: _isNew(items[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.isNew});

  final AppNotification item;

  /// Arrived since the operator last opened this screen. Shown as a dot and a
  /// soft glow - not as a coloured card, because the card colour means "this
  /// still needs you", which is a different thing and outlives being read.
  final bool isNew;

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
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
          boxShadow: isNew
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          color: item.actionRequired ? color.withValues(alpha: 0.06) : null,
          shape: item.actionRequired
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
                          AnimatedSize(
                            duration: AppMotion.normal,
                            curve: AppMotion.decelerate,
                            child: isNew
                                ? Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 7),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isNew
                                    ? FontWeight.w700
                                    : FontWeight.w600,
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
