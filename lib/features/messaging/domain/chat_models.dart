/// Messaging domain types.
///
/// This module is deliberately self-contained: its own Firestore collections
/// (`chats`, `chats/{id}/messages`), its own models, its own screens. Nothing
/// in the ID-card pipeline imports it, and it imports nothing from that
/// pipeline. Chat is the part most likely to change shape later, and keeping
/// it isolated means those changes cannot destabilise card printing.
///
/// Note this is our own in-app chat, not WhatsApp. Reaching parents on
/// WhatsApp would require the official Business Cloud API with pre-approved
/// templates and explicit opt-in; unofficial bulk senders get numbers banned.
library;

/// What kind of conversation a chat document represents.
enum ChatKind {
  /// Admin office <-> one school.
  direct('Direct'),

  /// Admin broadcasting to many schools at once. Only the admin can post.
  broadcast('Announcement');

  const ChatKind(this.label);

  final String label;

  static ChatKind fromName(String? value) => ChatKind.values.firstWhere(
        (ChatKind k) => k.name == value,
        orElse: () => ChatKind.direct,
      );
}

/// A conversation.
class Chat {
  const Chat({
    required this.id,
    required this.title,
    required this.members,
    this.kind = ChatKind.direct,
    this.schoolId,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadFor = const <String>[],
  });

  final String id;
  final String title;

  /// Auth UIDs allowed in this conversation. Mirrored into the Firestore
  /// security rules, which check membership on every read and write.
  final List<String> members;

  final ChatKind kind;

  /// Which school this conversation is about, when it is a direct chat.
  final String? schoolId;

  /// Denormalised preview fields. Stored on the chat document so the list
  /// screen renders from one query instead of a sub-query per row.
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;

  /// UIDs with unread messages. An array rather than a per-user counter
  /// because Firestore cannot atomically increment a map key per recipient,
  /// and "is there anything new" is all the badge needs.
  final List<String> unreadFor;

  bool isUnreadFor(String uid) => unreadFor.contains(uid);

  /// How many people an announcement was addressed to, excluding [senderUid].
  ///
  /// The admin is a member of their own broadcast so it appears in their list
  /// as a record of what went out, but they are not a recipient of it.
  int recipientCount(String senderUid) =>
      members.where((String uid) => uid != senderUid).length;

  /// How many recipients have opened it.
  ///
  /// This is the only honest measure of "delivery" for a broadcast. Writing
  /// the announcement is one atomic batch - it lands for everyone or nobody -
  /// so there is no per-recipient send failure to count. What an admin
  /// actually wants to know is who has seen it, and [unreadFor] tracks that
  /// live as people open the conversation.
  int readCount(String senderUid) {
    final int total = recipientCount(senderUid);
    final int unread = unreadFor.where((String uid) => uid != senderUid).length;
    return (total - unread).clamp(0, total);
  }

  Chat copyWith({
    String? title,
    List<String>? members,
    ChatKind? kind,
    String? schoolId,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastSenderId,
    List<String>? unreadFor,
  }) {
    return Chat(
      id: id,
      title: title ?? this.title,
      members: members ?? this.members,
      kind: kind ?? this.kind,
      schoolId: schoolId ?? this.schoolId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadFor: unreadFor ?? this.unreadFor,
    );
  }

  Map<String, Object?> toFirestoreMap() => <String, Object?>{
        'title': title,
        'members': members,
        'kind': kind.name,
        'schoolId': schoolId,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt?.toUtc().toIso8601String(),
        'lastSenderId': lastSenderId,
        'unreadFor': unreadFor,
      };

  static Chat fromFirestoreMap(String id, Map<String, Object?> map) {
    return Chat(
      id: id,
      title: (map['title'] as String?) ?? 'Conversation',
      members: <String>[
        ...?(map['members'] as List<Object?>?)?.whereType<String>(),
      ],
      kind: ChatKind.fromName(map['kind'] as String?),
      schoolId: map['schoolId'] as String?,
      lastMessage: (map['lastMessage'] as String?) ?? '',
      lastMessageAt: DateTime.tryParse((map['lastMessageAt'] as String?) ?? ''),
      lastSenderId: map['lastSenderId'] as String?,
      unreadFor: <String>[
        ...?(map['unreadFor'] as List<Object?>?)?.whereType<String>(),
      ],
    );
  }
}

/// What a message carries.
enum MessageKind {
  text,
  image,
  document;

  static MessageKind fromName(String? value) => MessageKind.values.firstWhere(
        (MessageKind k) => k.name == value,
        orElse: () => MessageKind.text,
      );
}

/// One message in a conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    this.body = '',
    this.kind = MessageKind.text,
    this.attachmentUrl,
    this.attachmentName,
    this.readBy = const <String>[],
    this.pending = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final DateTime sentAt;

  final String body;
  final MessageKind kind;
  final String? attachmentUrl;
  final String? attachmentName;

  /// UIDs that have seen this message - drives the read receipt.
  final List<String> readBy;

  /// True while the message is still on its way to the server. Rendered with a
  /// clock icon so the sender can see it has not landed yet, rather than the
  /// message appearing sent and silently vanishing on a failed write.
  final bool pending;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  bool isReadBy(String uid) => readBy.contains(uid);

  ChatMessage copyWith({
    List<String>? readBy,
    bool? pending,
    String? attachmentUrl,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      sentAt: sentAt,
      body: body,
      kind: kind,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName,
      readBy: readBy ?? this.readBy,
      pending: pending ?? this.pending,
    );
  }

  Map<String, Object?> toFirestoreMap() => <String, Object?>{
        'senderId': senderId,
        'senderName': senderName,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'body': body,
        'kind': kind.name,
        'attachmentUrl': attachmentUrl,
        'attachmentName': attachmentName,
        'readBy': readBy,
      };

  static ChatMessage fromFirestoreMap(
    String id,
    String chatId,
    Map<String, Object?> map,
  ) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: (map['senderId'] as String?) ?? '',
      senderName: (map['senderName'] as String?) ?? 'Unknown',
      sentAt: DateTime.tryParse((map['sentAt'] as String?) ?? '') ?? DateTime.now(),
      body: (map['body'] as String?) ?? '',
      kind: MessageKind.fromName(map['kind'] as String?),
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      readBy: <String>[
        ...?(map['readBy'] as List<Object?>?)?.whereType<String>(),
      ],
    );
  }
}
