import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/features/notifications/domain/app_notification.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The operator's notification feed, newest first.
///
/// Assembled from live state rather than a stored table - see [AppNotification]
/// for why. Three sources feed it:
///   * entries whose review state moved (approved / sent back / printed),
///   * conversations with unread messages,
///   * uploads that have given up retrying.
final Provider<List<AppNotification>> notificationsProvider =
    Provider<List<AppNotification>>((Ref ref) {
  final List<StudentEntry> entries =
      ref.watch(entriesProvider).value ?? const <StudentEntry>[];
  final List<Chat> chats = ref.watch(myChatsProvider).value ?? const <Chat>[];
  final SessionUser? session = ref.watch(currentSessionProvider);

  final List<AppNotification> out = <AppNotification>[];

  for (final StudentEntry e in entries) {
    final AppNotification? n = AppNotification.forEntry(
      entryId: e.id,
      studentName: e.name,
      status: e.approvalStatus,
      reason: e.rejectionReason,
      // reviewedAt is when the office actually decided. Falling back to
      // updatedAt keeps a row from jumping to 1970 on a record that synced
      // before the review fields existed.
      at: e.reviewedAt ?? e.updatedAt,
    );
    if (n != null) out.add(n);

    // A failed upload is the operator's problem to notice - it means the card
    // has not reached the office at all, whatever its review status says.
    if (e.syncStatus == SyncStatus.failed) {
      out.add(
        AppNotification(
          id: 'entry-${e.id}-syncfail',
          kind: NotificationKind.syncFailed,
          title: 'Upload failed',
          body: e.syncError == null
              ? '${e.name} has not reached the office yet.'
              : '${e.name}: ${e.syncError}',
          at: e.updatedAt,
          route: '/sync',
          unread: true,
        ),
      );
    }
  }

  if (session != null) {
    for (final Chat c in chats) {
      if (!c.isUnreadFor(session.uid)) continue;
      final bool isBroadcast = c.kind == ChatKind.broadcast;
      out.add(
        AppNotification(
          id: 'chat-${c.id}',
          kind: isBroadcast
              ? NotificationKind.broadcast
              : NotificationKind.newMessage,
          title: isBroadcast ? 'Announcement' : 'New message',
          body: c.lastMessage.isEmpty
              ? c.title
              : '${c.title}: ${c.lastMessage}',
          at: c.lastMessageAt ?? DateTime.now(),
          route: '/messages/${c.id}',
          unread: true,
        ),
      );
    }
  }

  out.sort(
    (AppNotification a, AppNotification b) => b.at.compareTo(a.at),
  );
  return out;
});

/// Count for the badge on the Profile tab and the notifications icon.
final Provider<int> unreadNotificationCountProvider = Provider<int>((Ref ref) {
  return ref
      .watch(notificationsProvider)
      .where((AppNotification n) => n.unread)
      .length;
});
