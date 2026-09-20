import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_id_card/features/messaging/data/chat_repository.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/services/firebase/inline_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';

class _FakeStorage extends Mock implements FirebaseStorage {}

class _FakeRef extends Mock implements Reference {}

/// Sending a file in a conversation.
///
/// Reported repeatedly from the field: picking an image in a chat failed, and
/// the message never sent. The cause was the same one fact that stranded every
/// student photo - Cloud Storage is not provisioned on this project - and an
/// earlier change only made the error message readable, which is not the same
/// as making the feature work.
///
/// Attachments now fall back to travelling inside Firestore. These tests pin
/// the fallback, the size ceiling that comes with it, and the two rendering
/// bugs that would have made a working upload still look broken.
void main() {
  setUpAll(() {
    registerFallbackValue(File('fallback.png'));
    registerFallbackValue(SettableMetadata());
  });

  /// A camera-sized photo: far larger than a Firestore document can hold, so
  /// it exercises the resampling rather than just the base64 step.
  late Uint8List bigPhoto;

  setUpAll(() {
    final img.Image src = img.Image(width: 2400, height: 1800);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        src.setPixelRgb(x, y, (x * 7) % 256, (y * 5) % 256, (x + y) % 256);
      }
    }
    bigPhoto = Uint8List.fromList(img.encodeJpg(src, quality: 95));
  });

  group('Packaging an attachment', () {
    test('a camera photo is shrunk to fit a document', () async {
      final Object result = await encodeInlineAttachment(
        bytes: bigPhoto,
        contentType: 'image/jpeg',
      );

      expect(result, isA<InlineAttachment>());
      final InlineAttachment a = result as InlineAttachment;

      expect(a.dataBase64.length, lessThan(kMaxInlineAttachmentChars));
      expect(
        a.width,
        lessThanOrEqualTo(kInlineImageLongEdge),
        reason:
            'nobody needs a 12 MP frame in a chat bubble, and no document '
            'could hold one anyway',
      );
      expect(img.decodeJpg(base64Decode(a.dataBase64)), isNotNull);
    });

    test('and carries a thumbnail small enough for the thread', () async {
      final InlineAttachment a = await encodeInlineAttachment(
        bytes: bigPhoto,
        contentType: 'image/jpeg',
      ) as InlineAttachment;

      expect(a.thumbBase64, isNotNull);
      expect(
        a.thumbBase64!.length,
        lessThan(a.dataBase64.length),
        reason: 'the bubble shows this; the full frame is a separate read',
      );
      final img.Image? thumb = img.decodeJpg(base64Decode(a.thumbBase64!));
      expect(thumb, isNotNull);
      expect(thumb!.width, kInlineThumbLongEdge);
    });

    test('a small image is never enlarged', () async {
      final Uint8List small = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 200, height: 150)),
      );
      final InlineAttachment a = await encodeInlineAttachment(
        bytes: small,
        contentType: 'image/jpeg',
      ) as InlineAttachment;

      expect(
        a.width,
        200,
        reason: 'upscaling would inflate it towards the budget for no gain',
      );
    });

    test('a document is sent byte for byte, not re-encoded', () async {
      final Uint8List pdf = Uint8List.fromList(
        utf8.encode('%PDF-1.4 pretend document body'),
      );
      final InlineAttachment a = await encodeInlineAttachment(
        bytes: pdf,
        contentType: 'application/pdf',
      ) as InlineAttachment;

      expect(
        base64Decode(a.dataBase64),
        pdf,
        reason: 're-encoding a PDF would corrupt it',
      );
      expect(a.contentType, 'application/pdf');
      expect(a.thumbBase64, isNull, reason: 'nothing to preview');
    });

    test(
      'an oversized document is refused with a sentence, not a crash',
      () async {
        final Object result = await encodeInlineAttachment(
          bytes: Uint8List(900 * 1024),
          contentType: 'application/pdf',
        );

        expect(result, isA<InlineAttachmentFailure>());
        final InlineAttachmentFailure f = result as InlineAttachmentFailure;
        expect(
          f.message,
          contains('MB'),
          reason: 'the sender needs a size they can act on, not an error code',
        );
      },
    );

    test('unreadable image bytes are refused, not thrown', () async {
      // `decodeImage` probes each format and a truncated file can make one of
      // those probes read past the end and throw.
      final Object result = await encodeInlineAttachment(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        contentType: 'image/png',
      );
      expect(result, isA<InlineAttachmentFailure>());
    });
  });

  group('Sending into a conversation', () {
    late FakeFirebaseFirestore firestore;
    late _FakeStorage storage;
    late ChatRepository repo;
    late Directory tempDir;
    late Chat chat;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      storage = _FakeStorage();
      repo = ChatRepository(firestore: firestore, storage: storage);
      tempDir = Directory.systemTemp.createTempSync('id_entity_chat_test');

      // The state this exists for: no bucket.
      final _FakeRef ref = _FakeRef();
      when(() => storage.ref()).thenReturn(ref);
      when(() => ref.child(any())).thenReturn(ref);
      when(() => ref.putFile(any(), any())).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'bucket-not-found'),
      );

      chat = const Chat(
        id: 'chat-1',
        title: 'DEMO PUBLIC SCHOOL',
        schoolId: 'school-a',
        members: <String>['teacher-1', 'admin-1'],
      );
      await firestore.collection('chats').doc('chat-1').set(<String, Object?>{
        'title': chat.title,
        'members': chat.members,
      });
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File photoFile() =>
        File('${tempDir.path}/snap.jpg')..writeAsBytesSync(bigPhoto);

    Future<List<ChatMessage>> messages() async {
      final QuerySnapshot<Map<String, Object?>> snap = await firestore
          .collection('chats')
          .doc('chat-1')
          .collection('messages')
          .get();
      return snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, Object?>> d) =>
                ChatMessage.fromFirestoreMap(d.id, 'chat-1', d.data()),
          )
          .toList();
    }

    test('a photo sends even though Storage refuses it', () async {
      final String? problem = await repo.sendAttachment(
        chat: chat,
        senderId: 'teacher-1',
        senderName: 'TEACHER',
        body: '',
        file: photoFile(),
        fileName: 'snap.jpg',
      );

      expect(
        problem,
        isNull,
        reason: 'this is the bug: the message used to never send at all',
      );

      final List<ChatMessage> sent = await messages();
      expect(sent, hasLength(1));
      expect(sent.single.kind, MessageKind.image);
      expect(sent.single.attachmentInline, isTrue);
      expect(sent.single.attachmentThumb, isNotNull);
      expect(sent.single.hasAttachment, isTrue);
      expect(
        sent.single.attachmentUrl,
        isNull,
        reason: 'there is no Storage URL, and inventing one breaks rendering',
      );
    });

    test('the bytes land in their own document, not on the message', () async {
      await repo.sendAttachment(
        chat: chat,
        senderId: 'teacher-1',
        senderName: 'TEACHER',
        body: 'see this',
        file: photoFile(),
        fileName: 'snap.jpg',
      );

      final ChatMessage m = (await messages()).single;

      final String? uri = await repo.fetchInlineAttachment(
        chatId: 'chat-1',
        messageId: m.id,
      );
      expect(uri, isNotNull);
      expect(uri, startsWith('data:image/jpeg;base64,'));

      // The message itself stays small: a conversation loads every message at
      // once, so a full frame on each would mean downloading the whole
      // thread's pictures to read one line of text.
      expect(m.attachmentThumb!.length, lessThan(uri!.length ~/ 2));
    });

    test('the conversation preview updates so the list shows it', () async {
      await repo.sendAttachment(
        chat: chat,
        senderId: 'teacher-1',
        senderName: 'TEACHER',
        body: '',
        file: photoFile(),
        fileName: 'snap.jpg',
      );

      final Map<String, Object?> doc =
          (await firestore.collection('chats').doc('chat-1').get()).data() ??
          <String, Object?>{};

      expect(doc['lastMessage'], 'Photo');
      expect(doc['lastSenderId'], 'teacher-1');
      expect(doc['unreadFor'], <String>[
        'admin-1',
      ], reason: 'everyone except the sender now has something unread');
    });

    test('a rejected file type never reaches the network', () async {
      final File exe = File('${tempDir.path}/thing.exe')
        ..writeAsBytesSync(<int>[0, 1, 2]);

      final String? problem = await repo.sendAttachment(
        chat: chat,
        senderId: 'teacher-1',
        senderName: 'TEACHER',
        body: '',
        file: exe,
        fileName: 'thing.exe',
      );

      expect(problem, contains('Cannot send'));
      expect(await messages(), isEmpty);
    });

    test('an oversized file sends nothing and says why', () async {
      final File big = File('${tempDir.path}/huge.pdf')
        ..writeAsBytesSync(Uint8List(900 * 1024));

      final String? problem = await repo.sendAttachment(
        chat: chat,
        senderId: 'teacher-1',
        senderName: 'TEACHER',
        body: '',
        file: big,
        fileName: 'huge.pdf',
      );

      expect(problem, isNotNull);
      expect(
        await messages(),
        isEmpty,
        reason:
            'a message pointing at bytes that were never stored is worse '
            'than a refusal the sender can read',
      );
    });
  });

  group('What the bubble can render', () {
    ChatMessage message({
      String? url,
      String? thumb,
      bool inline = false,
      MessageKind kind = MessageKind.image,
    }) => ChatMessage(
      id: 'm1',
      chatId: 'chat-1',
      senderId: 'teacher-1',
      senderName: 'TEACHER',
      sentAt: DateTime(2026, 9, 18),
      kind: kind,
      attachmentUrl: url,
      attachmentThumb: thumb,
      attachmentInline: inline,
    );

    test('an inline attachment counts as having one', () {
      // `hasAttachment` used to test only the Storage URL, so an inline
      // attachment rendered as an ordinary empty text bubble.
      expect(message(inline: true, thumb: 'abc').hasAttachment, isTrue);
    });

    test('the preview falls back to the thumbnail when there is no URL', () {
      expect(
        message(inline: true, thumb: 'abc').imagePreviewSource,
        'abc',
        reason: 'the old code did `attachmentUrl!` here and crashed',
      );
    });

    test('a Storage URL still wins when one exists', () {
      expect(
        message(url: 'https://example/p.jpg', thumb: 'abc').imagePreviewSource,
        'https://example/p.jpg',
      );
    });

    test('a message with neither has nothing to draw, and says so', () {
      expect(message().imagePreviewSource, isNull);
      expect(message().hasAttachment, isFalse);
    });

    test('the wire format round-trips the inline fields', () {
      final ChatMessage original = message(
        inline: true,
        thumb: 'abc',
      ).copyWith();
      final ChatMessage back = ChatMessage.fromFirestoreMap(
        'm1',
        'chat-1',
        original.toFirestoreMap(),
      );

      expect(back.attachmentInline, isTrue);
      expect(back.attachmentThumb, 'abc');
    });

    test('a message from before this release still reads correctly', () {
      // No `attachmentInline` key at all on the document.
      final ChatMessage back = ChatMessage.fromFirestoreMap(
        'm1',
        'chat-1',
        <String, Object?>{
          'senderId': 'teacher-1',
          'senderName': 'TEACHER',
          'sentAt': DateTime(2026, 9, 1).toUtc().toIso8601String(),
          'kind': 'image',
          'attachmentUrl': 'https://example/old.jpg',
        },
      );

      expect(back.attachmentInline, isFalse);
      expect(back.imagePreviewSource, 'https://example/old.jpg');
    });
  });
}
