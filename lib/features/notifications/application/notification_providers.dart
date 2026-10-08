import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/features/notifications/domain/app_notification.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/providers/seen_marker_providers.dart';
import 'package:flutter_id_card/shared/services/local/app_flag_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When the operator last opened the notifications screen.
///
/// Kept as a record of the last visit. The badge is no longer counted against
/// it - see [notificationsProvider] - but the key is cheap to keep and
/// dropping it would be a migration for no gain.
final StreamProvider<DateTime?> notificationsSeenAtProvider =
    StreamProvider<DateTime?>((Ref ref) {
      return ref
          .watch(appFlagRepositoryProvider)
          .watchDateTime(AppFlagRepository.notificationsSeenAtKey);
    });

/// The operator's notification feed, newest first.
///
/// Assembled from live state rather than a stored table - see [AppNotification]
/// for why. Three sources feed it:
///   * entries whose review state moved (approved / sent back / printed),
///   * conversations with unread messages,
///   * uploads that have given up retrying.
final Provider<List<AppNotification>>
notificationsProvider = Provider<List<AppNotification>>((Ref ref) {
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
      reviewedAt: e.reviewedAt,
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
          actionRequired: true,
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
          // The last message's time is part of the id so a second message in
          // a conversation the operator has already glanced at is new again.
          // With a bare `chat-<id>`, reading the notification once silenced
          // that conversation for good.
          id: c.lastMessageAt == null
              ? 'chat-${c.id}'
              : 'chat-${c.id}-${c.lastMessageAt!.millisecondsSinceEpoch}',
          kind: isBroadcast
              ? NotificationKind.broadcast
              : NotificationKind.newMessage,
          title: isBroadcast ? 'Announcement' : 'New message',
          body: c.lastMessage.isEmpty
              ? c.title
              : '${c.title}: ${c.lastMessage}',
          at: c.lastMessageAt ?? DateTime.now(),
          route: '/messages/${c.id}',
          actionRequired: true,
        ),
      );
    }
  }

  out.sort((AppNotification a, AppNotification b) => b.at.compareTo(a.at));

  // Unread is decided here, against the set of ids already looked at, rather
  // than by each source.
  //
  // The sources used to hardcode it, and a returned card hardcoded it to true
  // forever - so the bell carried a number nothing could clear and the app
  // always looked like it was hiding something missed. Recording what has
  // been looked at is what makes "I have seen these" expressible at all: the
  // feed is derived from live state and has no rows of its own to mark read.
  //
  // It was a timestamp before this, and the timestamp was wrong in a way that
  // only showed up on a real handset. It was stamped with the device clock
  // while the feed's times come off the server, so a phone a few minutes slow
  // produced notifications dated after the moment they were read - and the
  // badge was back on the next launch, with nothing the operator could do
  // about it. Ids carry no clock. They also survive a reinstall, because
  // SeenMarkerService mirrors them onto the account.
  final Set<String> seen =
      ref.watch(notificationsSeenIdsProvider).value ?? const <String>{};
  return out
      .map((AppNotification n) => n.copyWith(unread: !seen.contains(n.id)))
      .toList();
});

/// Count for the badge on the Profile tab and the notifications icon.
///
/// Reaches zero once the operator opens the notifications screen, which is the
/// whole point: a badge that cannot be cleared is worse than no badge, because
/// it permanently signals a missed message that does not exist.
final Provider<int> unreadNotificationCountProvider = Provider<int>((Ref ref) {
  return ref
      .watch(notificationsProvider)
      .where((AppNotification n) => n.unread)
      .length;
});
