import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/data/chat_repository.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// One conversation: message history, composer, attachments and search.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final TextEditingController _search = TextEditingController();

  bool _searching = false;
  bool _sending = false;

  /// Ensures the read receipt write happens once per screen visit rather than
  /// on every stream rebuild, which would be a Firestore write per keystroke
  /// anyone else types.
  bool _markedRead = false;

  @override
  void dispose() {
    _composer.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<List<ChatMessage>> messagesAsync = ref.watch(
      messagesProvider(widget.chatId),
    );
    final Chat? chat = ref
        .watch(myChatsProvider)
        .value
        ?.where((Chat c) => c.id == widget.chatId)
        .firstOrNull;

    final List<ChatMessage> all = messagesAsync.value ?? const <ChatMessage>[];
    final List<ChatMessage> visible = _searching
        ? ChatRepository.search(all, _search.text)
        : all;

    if (!_markedRead && all.isNotEmpty && session != null) {
      _markedRead = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _markRead(all, session),
      );
    }

    final bool canPost =
        chat == null ||
        chat.kind != ChatKind.broadcast ||
        (session?.isAdmin ?? false);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search messages',
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : Text(chat?.title ?? 'Conversation'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search messages',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (chat?.kind == ChatKind.broadcast) const _BroadcastBanner(),
          Expanded(
            child: SmoothSwitcher(
              alignment: Alignment.center,
              child: messagesAsync.when(
                loading: () => const Center(
                  key: ValueKey<String>('loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (Object e, StackTrace s) => Center(
                  key: const ValueKey<String>('error'),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('Could not load messages: $e'),
                  ),
                ),
                data: (_) => visible.isEmpty
                    ? _EmptyMessages(searching: _searching)
                    : ListView.builder(
                        key: const ValueKey<String>('messages'),
                        // Newest at the bottom, which is what a chat should do,
                        // achieved by reversing both the list and the query
                        // order rather than scrolling after every frame.
                        reverse: true,
                        padding: const EdgeInsets.all(AppTheme.gutter),
                        itemCount: visible.length,
                        itemBuilder: (BuildContext context, int i) =>
                            _MessageBubble(
                              // Keyed by message id so a bubble arriving at the
                              // bottom animates in on its own rather than the whole
                              // reversed list shuffling up.
                              key: ValueKey<String>(visible[i].id),
                              message: visible[i],
                              isMine: visible[i].senderId == session?.uid,
                              memberCount: chat?.members.length ?? 2,
                            ),
                      ),
              ),
            ),
          ),
          if (canPost)
            _Composer(
              controller: _composer,
              sending: _sending,
              onSend: () => _send(chat, session),
              onAttach: () => _attach(chat, session),
            )
          else
            const _ReadOnlyFooter(),
        ],
      ),
    );
  }

  Future<void> _markRead(
    List<ChatMessage> messages,
    SessionUser session,
  ) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .markRead(chatId: widget.chatId, uid: session.uid, visible: messages);
    } on Object {
      // A failed read receipt is cosmetic - never interrupt the reader for it.
    }
  }

  Future<void> _send(Chat? chat, SessionUser? session) async {
    final String text = _composer.text.trim();
    if (text.isEmpty || chat == null || session == null || _sending) return;

    setState(() => _sending = true);
    // Cleared up front so the field feels instant; restored on failure below.
    _composer.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chat: chat,
            senderId: session.uid,
            senderName: session.displayName.isEmpty
                ? session.email
                : session.displayName,
            body: text,
          );
    } on Object catch (e) {
      if (!mounted) return;
      _composer.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send: $e'),
          backgroundColor: StatusColors.failed,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Turns an attachment failure into something the sender can act on.
  ///
  /// Cloud Storage is not provisioned on this Firebase project, so every
  /// attachment fails with a raw `[firebase_storage/object-not-found] No object
  /// exists at the desired reference.` Showing that verbatim reads like the app
  /// is broken, when in fact the feature simply is not switched on yet and
  /// nothing the sender does will change it.
  static String _describeAttachmentFailure(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'object-not-found' || 'bucket-not-found' || 'project-not-found' =>
          'Attachments are not switched on for this project yet, so the file '
              'could not be sent. Text messages work normally.',
        'unauthorized' || 'permission-denied' =>
          'You do not have permission to attach files to this conversation.',
        'unauthenticated' => 'Signed out. Sign in again to send the file.',
        'quota-exceeded' => 'File storage is full. Tell the office.',
        'canceled' => 'The upload was cancelled.',
        'retry-limit-exceeded' =>
          'The upload kept timing out. Check the connection and try again.',
        _ => error.message ?? 'Could not send the file (${error.code}).',
      };
    }
    return 'Could not send the file. Check the connection and try again.';
  }

  Future<void> _attach(Chat? chat, SessionUser? session) async {
    if (chat == null || session == null) return;

    // file_picker 12 exposes static methods and a dedicated single-file
    // `pickFile` that returns the PlatformFile directly.
    final PlatformFile? picked = await FilePicker.pickFile();

    // `path` is null for web-picked files, which have no filesystem path. This
    // module is Android/desktop only for now, so treat that as "nothing to
    // attach" rather than crashing on a null assertion.
    final String? path = picked?.path;
    if (picked == null || path == null) return;

    final File file = File(path);
    final String name = picked.name;

    // Checked here rather than letting the upload bounce off the Storage
    // rules: a rule rejection surfaces as a raw Firebase permission error,
    // which reads like a broken app instead of "we don't accept that file".
    if (ChatRepository.contentTypeFor(name) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot send "$name". Attachments must be a photo, PDF, text, '
            'Word or Excel file.',
          ),
          backgroundColor: StatusColors.failed,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      // One call, because the caller should not have to know which route the
      // file took. Storage is tried first and Firestore is the fallback; both
      // end with the message in the thread.
      final String? problem = await ref
          .read(chatRepositoryProvider)
          .sendAttachment(
            chat: chat,
            senderId: session.uid,
            senderName: session.displayName.isEmpty
                ? session.email
                : session.displayName,
            body: _composer.text.trim(),
            file: file,
            fileName: name,
          );

      if (!mounted) return;
      if (problem != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(problem),
            backgroundColor: StatusColors.failed,
          ),
        );
      } else {
        _composer.clear();
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_describeAttachmentFailure(e)),
          backgroundColor: StatusColors.failed,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.memberCount,
  });

  final ChatMessage message;
  final bool isMine;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Everyone except the sender has seen it.
    final bool readByAll = message.readBy.length >= memberCount;

    return FadeSlideIn(
      // Slides in from the side it belongs to, which is the direction a
      // message actually travels. Zero stagger: in a chat every bubble is
      // already on screen, and a delay would make scrolling back feel laggy.
      offset: 6,
      duration: AppMotion.fast,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMine ? 14 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (message.hasAttachment) ...<Widget>[
                _MessageAttachment(message: message),
                if (message.body.isNotEmpty) const SizedBox(height: 6),
              ],
              if (message.body.isNotEmpty)
                Text(
                  message.body,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateFormat('HH:mm').format(message.sentAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isMine) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      message.pending
                          ? Icons.schedule
                          : (readByAll ? Icons.done_all : Icons.done),
                      size: 13,
                      color: readByAll
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a message's attachment looks like in the bubble.
///
/// Handles both routes an attachment can arrive by - a Cloud Storage URL, or
/// base64 carried inside Firestore - because a conversation can contain both
/// and a bubble has no business knowing which.
///
/// The previous version rendered `Image.network(message.attachmentUrl!)`. That
/// was two bugs in one line: the bang crashes on an inline attachment, which
/// has no URL at all, and a document rendered as a bare filename with nothing
/// to tap. Since Storage has never worked on this project, the first case is
/// now the *only* case.
class _MessageAttachment extends ConsumerWidget {
  const _MessageAttachment({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.kind == MessageKind.image) {
      final String? preview = message.imagePreviewSource;
      if (preview == null) {
        return const _AttachmentChip(
          label: 'Image unavailable',
          icon: Icons.broken_image_outlined,
        );
      }

      return PressableSurface(
        onTap: () => _openFullScreen(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: message.attachmentInline
              ? Image.memory(
                  base64Decode(preview),
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                      const _AttachmentChip(
                        label: 'Image unavailable',
                        icon: Icons.broken_image_outlined,
                      ),
                )
              : Image.network(
                  preview,
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                      const _AttachmentChip(
                        label: 'Image unavailable',
                        icon: Icons.broken_image_outlined,
                      ),
                ),
        ),
      );
    }

    return PressableSurface(
      onTap: () => _openDocument(context, ref),
      child: _AttachmentChip(
        label: message.attachmentName ?? 'Document',
        icon: Icons.insert_drive_file_outlined,
        subtitle: message.attachmentBytes == null
            ? null
            : _formatBytes(message.attachmentBytes!),
      ),
    );
  }

  /// Full resolution, fetched on demand.
  ///
  /// The bubble shows a 256 px thumbnail; the frame behind it is a separate
  /// document and is read only when someone actually wants to look at it.
  /// Fetching it for every picture in a thread would undo the whole reason
  /// the two are stored apart.
  Future<void> _openFullScreen(BuildContext context, WidgetRef ref) async {
    final NavigatorState navigator = Navigator.of(context);
    Future<String?>? pending;
    if (message.attachmentInline) {
      pending = ref
          .read(chatRepositoryProvider)
          .fetchInlineAttachment(chatId: message.chatId, messageId: message.id);
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext _) =>
            _FullScreenImage(message: message, fullData: pending),
      ),
    );
  }

  /// Writes the attachment to a temporary file and hands it to the platform.
  ///
  /// There is no in-app viewer for a PDF or a spreadsheet and there should not
  /// be; the phone already has apps that do this properly.
  Future<void> _openDocument(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      if (!message.attachmentInline) {
        final String? url = message.attachmentUrl;
        if (url == null || url.isEmpty) return;
        await OpenFilex.open(url);
        return;
      }

      final String? dataUri = await ref
          .read(chatRepositoryProvider)
          .fetchInlineAttachment(chatId: message.chatId, messageId: message.id);
      if (dataUri == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('That attachment is no longer available.'),
          ),
        );
        return;
      }

      final int comma = dataUri.indexOf(',');
      final Uint8List bytes = base64Decode(dataUri.substring(comma + 1));
      final Directory dir = await getTemporaryDirectory();
      final File out = File(
        '${dir.path}/${message.attachmentName ?? 'attachment'}',
      );
      await out.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(out.path);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open that attachment: $e'),
          backgroundColor: StatusColors.failed,
        ),
      );
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// The attachment at full size, pinchable.
class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.message, required this.fullData});

  final ChatMessage message;

  /// Resolves to a data URI for an inline attachment, or null when the image
  /// came from Storage and the URL is already the full frame.
  final Future<String?>? fullData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          message.attachmentName ?? 'Photo',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: fullData == null
              ? Image.network(message.attachmentUrl!)
              : FutureBuilder<String?>(
                  future: fullData,
                  builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                    // The thumbnail is already decoded and is recognisably the
                    // right picture, so it stands in rather than a spinner on
                    // an empty screen.
                    final String? full = snap.data;
                    if (full == null) {
                      final String? thumb = message.attachmentThumb;
                      if (thumb == null) {
                        return const CircularProgressIndicator(
                          color: Colors.white,
                        );
                      }
                      return Image.memory(base64Decode(thumb));
                    }
                    final int comma = full.indexOf(',');
                    return Image.memory(
                      base64Decode(full.substring(comma + 1)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.label,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: 'Attach a file',
              onPressed: sending ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  isDense: true,
                ),
                onSubmitted: (_) => sending ? null : onSend(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: sending
                    ? const SizedBox(
                        key: ValueKey<bool>(true),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send, key: ValueKey<bool>(false)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastBanner extends StatelessWidget {
  const _BroadcastBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.campaign_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Announcement - only the admin office can post here.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyFooter extends StatelessWidget {
  const _ReadOnlyFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          'You cannot reply to an announcement.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({required this.searching});

  final bool searching;

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
              searching ? Icons.search_off : Icons.chat_bubble_outline,
              size: 46,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No messages match' : 'No messages yet',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
