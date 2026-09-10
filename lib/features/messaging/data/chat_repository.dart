import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:uuid/uuid.dart';

/// Firestore access for the messaging module.
///
/// Unlike the ID-card side, chat is **online-only**: messages live in Firestore
/// and are read through live snapshot listeners rather than being mirrored into
/// the local Drift database. That is a deliberate difference. Card data must
/// survive a full day with no signal because re-capturing it means revisiting
/// the school; a chat message that fails to send can simply be retyped, and
/// building an offline outbox for it would add a second sync engine to
/// maintain for far less benefit.
///
/// Firestore's own offline cache still covers short dropouts.
class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestoreOverride = firestore,
        _storageOverride = storage;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;

  static const Uuid _uuid = Uuid();

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _bucket => _storageOverride ?? FirebaseStorage.instance;

  CollectionReference<Map<String, Object?>> get _chats => _db.collection('chats');

  // ------------------------------------------------------------------
  // Chats
  // ------------------------------------------------------------------

  /// Conversations this user belongs to, most recent first.
  Stream<List<Chat>> watchChatsFor(String uid) {
    return _chats
        .where('members', arrayContains: uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, Object?>> snap) {
      final List<Chat> chats = snap.docs
          .map((QueryDocumentSnapshot<Map<String, Object?>> d) =>
              Chat.fromFirestoreMap(d.id, d.data()))
          .toList();

      // Sorted client-side rather than with orderBy so the query needs no
      // composite index alongside the arrayContains filter - one less piece of
      // Firebase configuration to get wrong during deployment. Chat lists are
      // small enough that this costs nothing.
      chats.sort((Chat a, Chat b) {
        final DateTime aAt = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bAt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
      return chats;
    });
  }

  Future<Chat> createChat({
    required String title,
    required List<String> members,
    ChatKind kind = ChatKind.direct,
    String? schoolId,
  }) async {
    final String id = _uuid.v4();
    final Chat chat = Chat(
      id: id,
      title: title,
      members: members,
      kind: kind,
      schoolId: schoolId,
    );
    await _chats.doc(id).set(chat.toFirestoreMap());
    return chat;
  }

  // ------------------------------------------------------------------
  // Messages
  // ------------------------------------------------------------------

  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 200}) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, Object?>> snap) => snap.docs
              .map((QueryDocumentSnapshot<Map<String, Object?>> d) =>
                  ChatMessage.fromFirestoreMap(d.id, chatId, d.data()))
              .toList(),
        );
  }

  /// Posts a message and updates the conversation's preview fields.
  ///
  /// Both writes go in one batch: a message that exists but never appears in
  /// the chat list, or a preview pointing at a message that failed to write,
  /// are both worse than the whole send failing cleanly.
  Future<void> sendMessage({
    required Chat chat,
    required String senderId,
    required String senderName,
    required String body,
    MessageKind kind = MessageKind.text,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final String messageId = _uuid.v4();
    final DateTime now = DateTime.now();

    final ChatMessage message = ChatMessage(
      id: messageId,
      chatId: chat.id,
      senderId: senderId,
      senderName: senderName,
      sentAt: now,
      body: body,
      kind: kind,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      // The sender has trivially read their own message.
      readBy: <String>[senderId],
    );

    final WriteBatch batch = _db.batch();

    batch.set(
      _chats.doc(chat.id).collection('messages').doc(messageId),
      message.toFirestoreMap(),
    );

    batch.update(_chats.doc(chat.id), <String, Object?>{
      'lastMessage': _preview(message),
      'lastMessageAt': now.toUtc().toIso8601String(),
      'lastSenderId': senderId,
      // Everyone except the sender now has something unread.
      'unreadFor':
          chat.members.where((String uid) => uid != senderId).toList(),
    });

    await batch.commit();
  }

  static String _preview(ChatMessage m) => switch (m.kind) {
        MessageKind.text => m.body,
        MessageKind.image => 'Photo',
        MessageKind.document => m.attachmentName ?? 'Document',
      };

  /// Marks the conversation read for [uid] and stamps read receipts on the
  /// messages they had not seen.
  Future<void> markRead({
    required String chatId,
    required String uid,
    required List<ChatMessage> visible,
  }) async {
    final List<ChatMessage> unseen = visible
        .where((ChatMessage m) => m.senderId != uid && !m.isReadBy(uid))
        .toList();

    // Nothing to do - avoid a pointless write on every screen open.
    if (unseen.isEmpty) return;

    final WriteBatch batch = _db.batch();

    batch.update(_chats.doc(chatId), <String, Object?>{
      'unreadFor': FieldValue.arrayRemove(<String>[uid]),
    });

    for (final ChatMessage m in unseen) {
      batch.update(
        _chats.doc(chatId).collection('messages').doc(m.id),
        <String, Object?>{'readBy': FieldValue.arrayUnion(<String>[uid])},
      );
    }

    await batch.commit();
  }

  /// Uploads an attachment and returns its download URL.
  ///
  /// The content type is set explicitly rather than left to the SDK. The
  /// Storage rules allowlist attachment types, and an upload with no declared
  /// type arrives as `application/octet-stream` and is rejected - so guessing
  /// here is what keeps a legitimate photo or PDF from bouncing.
  Future<String> uploadAttachment({
    required String chatId,
    required File file,
    required String fileName,
  }) async {
    final Reference ref = _bucket
        .ref()
        .child('chats')
        .child(chatId)
        .child('${_uuid.v4()}_$fileName');

    await ref.putFile(
      file,
      SettableMetadata(contentType: contentTypeFor(fileName)),
    );
    return ref.getDownloadURL();
  }

  /// Maps a filename to the MIME type the Storage rules expect.
  ///
  /// Deliberately mirrors the allowlist in `firebase/storage.rules`: if a type
  /// is added there it has to be added here too, or the client will label the
  /// file in a way the server refuses. Returns null for anything unrecognised,
  /// which lets the upload fail loudly at the rule rather than silently
  /// landing an unlabelled blob in the bucket.
  static String? contentTypeFor(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    final String ext = fileName.substring(dot + 1).toLowerCase();

    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'bmp' => 'image/bmp',
      'pdf' => 'application/pdf',
      'txt' || 'csv' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => null,
    };
  }

  /// Client-side message search.
  ///
  /// Firestore has no substring search, and wiring up a search service for a
  /// few hundred messages per school would be disproportionate. Filtering the
  /// already-loaded window is enough at this scale; if conversations ever grow
  /// large enough for it to matter, that is the point to add a real index.
  static List<ChatMessage> search(List<ChatMessage> messages, String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return messages;
    return messages
        .where((ChatMessage m) =>
            m.body.toLowerCase().contains(needle) ||
            m.senderName.toLowerCase().contains(needle) ||
            (m.attachmentName?.toLowerCase().contains(needle) ?? false))
        .toList();
  }
}
