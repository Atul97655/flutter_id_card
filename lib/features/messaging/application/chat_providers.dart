import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/data/chat_repository.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) => ChatRepository());

/// Conversations for the signed-in user.
///
/// Emits an empty list rather than an error when Firebase is unavailable or
/// nobody is signed in, so the screen shows its empty state instead of a red
/// error box for what is a perfectly normal situation.
final StreamProvider<List<Chat>> myChatsProvider =
    StreamProvider<List<Chat>>((Ref ref) {
  final SessionUser? session = ref.watch(currentSessionProvider);

  if (session == null ||
      session.isOfflineTestSession ||
      !FirebaseBootstrap.instance.isReady) {
    return Stream<List<Chat>>.value(const <Chat>[]);
  }

  return ref.watch(chatRepositoryProvider).watchChatsFor(session.uid);
});

/// Live messages for one conversation.
final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((Ref ref, String chatId) {
  if (!FirebaseBootstrap.instance.isReady) {
    return Stream<List<ChatMessage>>.value(const <ChatMessage>[]);
  }
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});

/// The one conversation an operator has with the admin.
///
/// The plan fixes messaging as hub-and-spoke: a teacher opening the app sees
/// exactly one conversation, the Admin's. Broadcasts are excluded because they
/// are announcements, not somewhere a reply belongs.
///
/// Null when the admin has not opened the conversation yet - only an admin can
/// create one, so a teacher with no chat has nobody to write to and the UI must
/// say so rather than offering a dead button.
final Provider<Chat?> adminChatProvider = Provider<Chat?>((Ref ref) {
  final List<Chat> chats = ref.watch(myChatsProvider).value ?? const <Chat>[];
  for (final Chat c in chats) {
    if (c.kind != ChatKind.broadcast) return c;
  }
  return null;
});

/// Every announcement the admin has sent, newest first.
///
/// Broadcasts need no table of their own: one broadcast IS one chat document,
/// so the conversation list already is the archive. That also means the
/// delivery report stays live rather than being a snapshot frozen at send
/// time - `unreadFor` shrinks as recipients open it.
final Provider<List<Chat>> sentBroadcastsProvider =
    Provider<List<Chat>>((Ref ref) {
  final List<Chat> chats = ref.watch(myChatsProvider).value ?? const <Chat>[];
  final List<Chat> broadcasts = chats
      .where((Chat c) => c.kind == ChatKind.broadcast)
      .toList()
    ..sort((Chat a, Chat b) {
      final DateTime x = a.lastMessageAt ?? DateTime(1970);
      final DateTime y = b.lastMessageAt ?? DateTime(1970);
      return y.compareTo(x);
    });
  return broadcasts;
});

/// Total unread conversations, for the badge on the home screen.
final Provider<int> unreadChatCountProvider = Provider<int>((Ref ref) {
  final SessionUser? session = ref.watch(currentSessionProvider);
  final List<Chat> chats = ref.watch(myChatsProvider).value ?? const <Chat>[];
  if (session == null) return 0;
  return chats.where((Chat c) => c.isUnreadFor(session.uid)).length;
});
