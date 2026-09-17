import 'package:flutter_id_card/shared/models/approval_status.dart';

/// What a notification is telling the operator about.
enum NotificationKind {
  cardApproved,
  cardRejected,
  cardPrinted,
  newMessage,
  broadcast,
  syncFailed,
}

/// One row in the notifications feed.
///
/// These are **derived**, not stored. The feed is computed from state the app
/// already holds - entry approval statuses, unread conversations, failed
/// uploads - rather than from a notifications table that would have to be kept
/// in step with that state and would drift from it the moment a sync landed.
///
/// The consequence is that the feed always agrees with the rest of the app: a
/// card that gets re-approved cannot leave a stale "sent back" row behind.
/// Push delivery (FCM) is a separate concern and is not wired up - the app has
/// the dependency but no token registration or Cloud Function, so these arrive
/// only while the app is open.
///
/// ## Unread vs. needs-action
///
/// These are two different questions and were previously conflated, with the
/// result that the badge could never reach zero. A returned card was hardcoded
/// as unread forever, so the bell showed a count the operator had no way to
/// clear - it read as "you have missed something" permanently, which trains
/// people to ignore the badge entirely.
///
/// So: [unread] is "you have not looked at this yet" and is decided by the
/// feed against a persisted watermark, not by this class. [actionRequired] is
/// "this still needs you to do something", which stays true until the card is
/// actually resubmitted - it drives the row's highlight, and nothing else.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.route,
    this.unread = false,
    this.actionRequired = false,
  });

  /// Stable across rebuilds so a list animation does not re-key every frame.
  final String id;

  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;

  /// Where tapping it goes. Null for anything with nowhere useful to land.
  final String? route;

  /// Whether the operator has yet to look at this. Drives the badge count.
  final bool unread;

  /// Whether this still needs the operator to do something about it, however
  /// many times they have seen it. Drives the row's highlight, never the
  /// badge - a returned card that has been read is still a returned card, but
  /// it is not a missed notification.
  final bool actionRequired;

  AppNotification copyWith({bool? unread}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    at: at,
    route: route,
    unread: unread ?? this.unread,
    actionRequired: actionRequired,
  );

  /// A notification for an entry whose review state changed.
  ///
  /// Returns null for [ApprovalStatus.pending]: "still waiting" is the absence
  /// of news, and a feed that announces it would bury the states that matter.
  static AppNotification? forEntry({
    required String entryId,
    required String studentName,
    required ApprovalStatus status,
    required String? reason,
    required DateTime at,
  }) {
    final String name = studentName.trim().isEmpty ? 'A card' : studentName;
    final String route = '/submissions/$entryId';

    return switch (status) {
      ApprovalStatus.pending => null,
      ApprovalStatus.approved => AppNotification(
        id: 'entry-$entryId-approved',
        kind: NotificationKind.cardApproved,
        title: 'Card approved',
        body: '$name was approved by the office.',
        at: at,
        route: route,
      ),
      ApprovalStatus.rejected => AppNotification(
        id: 'entry-$entryId-rejected',
        kind: NotificationKind.cardRejected,
        title: 'Card sent back',
        body: reason == null || reason.trim().isEmpty
            ? '$name needs a correction.'
            : '$name: $reason',
        at: at,
        route: route,
        // A returned card is the one state that needs the operator to act,
        // so it stays highlighted until they deal with it. Highlighted - not
        // counted: see the class doc.
        actionRequired: true,
      ),
      ApprovalStatus.printed => AppNotification(
        id: 'entry-$entryId-printed',
        kind: NotificationKind.cardPrinted,
        title: 'Card printed',
        body: "$name's card has been printed.",
        at: at,
        route: route,
      ),
    };
  }
}
