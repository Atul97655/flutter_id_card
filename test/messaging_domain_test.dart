import 'package:flutter_id_card/features/messaging/data/chat_repository.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The messaging module had no tests at all.
///
/// It carries the plan's hub-and-spoke rules, read receipts and the attachment
/// contract that the Storage rules enforce, so the parts that can be exercised
/// without a network are worth pinning down.
void main() {
  group('ChatKind', () {
    test('round-trips through its wire name', () {
      for (final ChatKind k in ChatKind.values) {
        expect(ChatKind.fromName(k.name), k);
      }
    });

    test('an unknown kind degrades to direct, not broadcast', () {
      // Broadcast is the privileged shape - only an admin may post into one.
      // A value nobody recognises must never be promoted to it.
      expect(ChatKind.fromName('megaphone'), ChatKind.direct);
      expect(ChatKind.fromName(null), ChatKind.direct);
      expect(ChatKind.fromName(''), ChatKind.direct);
    });
  });

  group('MessageKind', () {
    test('round-trips through its wire name', () {
      for (final MessageKind k in MessageKind.values) {
        expect(MessageKind.fromName(k.name), k);
      }
    });

    test('an unknown kind reads as plain text', () {
      expect(MessageKind.fromName('video'), MessageKind.text);
      expect(MessageKind.fromName(null), MessageKind.text);
    });
  });

  group('Chat serialisation', () {
    Chat sample() => Chat(
          id: 'c1',
          title: 'ST JOHN SAMARITAN',
          members: const <String>['admin', 'teacher-a'],
          kind: ChatKind.direct,
          schoolId: 'school-a',
          lastMessage: 'Cards are ready',
          lastMessageAt: DateTime.utc(2026, 9, 10, 8, 30),
          lastSenderId: 'admin',
          unreadFor: const <String>['teacher-a'],
        );

    test('survives a Firestore round trip', () {
      final Chat original = sample();
      final Chat back = Chat.fromFirestoreMap(
        original.id,
        original.toFirestoreMap(),
      );

      expect(back.title, original.title);
      expect(back.members, original.members);
      expect(back.kind, original.kind);
      expect(back.schoolId, original.schoolId);
      expect(back.lastMessage, original.lastMessage);
      expect(back.lastMessageAt, original.lastMessageAt);
      expect(back.unreadFor, original.unreadFor);
    });

    test('a document with nothing in it does not throw', () {
      // Firestore hands back whatever is there. A half-written document must
      // render as an empty conversation, not crash the chat list.
      final Chat c = Chat.fromFirestoreMap('c1', <String, Object?>{});

      expect(c.id, 'c1');
      expect(c.title, 'Conversation');
      expect(c.members, isEmpty);
      expect(c.kind, ChatKind.direct);
      expect(c.unreadFor, isEmpty);
      expect(c.lastMessageAt, isNull);
    });

    test('non-string junk in the member arrays is dropped, not fatal', () {
      final Chat c = Chat.fromFirestoreMap('c1', <String, Object?>{
        'members': <Object?>['admin', 42, null, 'teacher-a'],
        'unreadFor': <Object?>[null, 'teacher-a'],
      });

      expect(c.members, <String>['admin', 'teacher-a']);
      expect(c.unreadFor, <String>['teacher-a']);
    });

    test('an unparseable timestamp reads as null rather than 1970', () {
      final Chat c = Chat.fromFirestoreMap('c1', <String, Object?>{
        'lastMessageAt': 'yesterday',
      });
      expect(c.lastMessageAt, isNull);
    });
  });

  group('Unread tracking', () {
    test('isUnreadFor only reports the people actually listed', () {
      const Chat c = Chat(
        id: 'c1',
        title: 'T',
        members: <String>['admin', 'a', 'b'],
        unreadFor: <String>['a'],
      );

      expect(c.isUnreadFor('a'), isTrue);
      expect(c.isUnreadFor('b'), isFalse);
      expect(c.isUnreadFor('admin'), isFalse);
      expect(c.isUnreadFor('nobody'), isFalse);
    });
  });

  group('ChatMessage', () {
    ChatMessage sample({
      MessageKind kind = MessageKind.text,
      String? attachmentUrl,
    }) =>
        ChatMessage(
          id: 'm1',
          chatId: 'c1',
          senderId: 'admin',
          senderName: 'Office',
          sentAt: DateTime.utc(2026, 9, 10, 9),
          body: 'Cards are ready',
          kind: kind,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentUrl == null ? null : 'sheet.pdf',
          readBy: const <String>['admin'],
        );

    test('survives a Firestore round trip', () {
      final ChatMessage original = sample(
        kind: MessageKind.document,
        attachmentUrl: 'https://example/sheet.pdf',
      );
      final ChatMessage back = ChatMessage.fromFirestoreMap(
        original.id,
        original.chatId,
        original.toFirestoreMap(),
      );

      expect(back.senderId, original.senderId);
      expect(back.senderName, original.senderName);
      expect(back.sentAt, original.sentAt);
      expect(back.body, original.body);
      expect(back.kind, MessageKind.document);
      expect(back.attachmentUrl, original.attachmentUrl);
      expect(back.attachmentName, original.attachmentName);
      expect(back.readBy, original.readBy);
    });

    test('an empty document degrades safely', () {
      final ChatMessage m =
          ChatMessage.fromFirestoreMap('m1', 'c1', <String, Object?>{});

      expect(m.senderId, '');
      expect(m.senderName, 'Unknown');
      expect(m.body, '');
      expect(m.kind, MessageKind.text);
      expect(m.readBy, isEmpty);
    });

    test('hasAttachment is false for an empty url, not just null', () {
      expect(sample().hasAttachment, isFalse);
      expect(sample(attachmentUrl: '').hasAttachment, isFalse);
      expect(sample(attachmentUrl: 'https://x/y.png').hasAttachment, isTrue);
    });

    test('read receipts are additive and do not disturb the body', () {
      final ChatMessage m = sample();
      expect(m.isReadBy('teacher-a'), isFalse);

      final ChatMessage read = m.copyWith(
        readBy: <String>[...m.readBy, 'teacher-a'],
      );

      expect(read.isReadBy('teacher-a'), isTrue);
      expect(read.isReadBy('admin'), isTrue);
      expect(read.body, m.body, reason: 'messages are immutable except readBy');
      expect(read.sentAt, m.sentAt);
    });

    test('a pending message is marked so the sender can see it is in flight',
        () {
      expect(sample().pending, isFalse);
      expect(sample().copyWith(pending: true).pending, isTrue);
    });
  });

  group('Attachment content types', () {
    // These mirror the allowlist in firebase/storage.rules. If a type is added
    // there it must be added here too, or the client will label a file in a
    // way the server refuses - so this test is the tripwire for that pairing.
    test('maps the types the Storage rules accept', () {
      const Map<String, String> expected = <String, String>{
        'photo.jpg': 'image/jpeg',
        'photo.JPEG': 'image/jpeg',
        'scan.png': 'image/png',
        'anim.gif': 'image/gif',
        'shot.webp': 'image/webp',
        'iphone.HEIC': 'image/heic',
        'old.bmp': 'image/bmp',
        'sheet.pdf': 'application/pdf',
        'notes.txt': 'text/plain',
        'data.csv': 'text/plain',
        'letter.doc': 'application/msword',
        'roster.xls': 'application/vnd.ms-excel',
      };

      expected.forEach((String name, String type) {
        expect(ChatRepository.contentTypeFor(name), type, reason: name);
      });

      expect(
        ChatRepository.contentTypeFor('letter.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        ChatRepository.contentTypeFor('roster.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test('refuses anything the rules would bounce', () {
      for (final String name in <String>[
        'payload.exe',
        'script.sh',
        'app.apk',
        'archive.zip',
        'noextension',
        'trailingdot.',
        '',
      ]) {
        expect(
          ChatRepository.contentTypeFor(name),
          isNull,
          reason: '$name should be refused before upload, not at the rule',
        );
      }
    });

    test('is case-insensitive about the extension', () {
      expect(ChatRepository.contentTypeFor('A.PdF'), 'application/pdf');
    });

    test('uses the last dot, so a dotted filename still works', () {
      expect(
        ChatRepository.contentTypeFor('class.10.roster.pdf'),
        'application/pdf',
      );
    });
  });
}
