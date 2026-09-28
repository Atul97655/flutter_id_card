import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/card_render/application/card_render_providers.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/messaging/application/card_share_service.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/data/chat_repository.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/features/messaging/presentation/send_id_card_screen.dart';
import 'package:flutter_id_card/features/messaging/presentation/widgets/attachment_tray.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
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

    return GlassScaffold(
      backdrop: GlassBackdrop.chat,
      resizeToAvoidBottomInset: true,
      header: _ChatHeader(
        title: chat?.title ?? 'Conversation',
        subtitle: _presenceLine(chat),
        searching: _searching,
        searchController: _search,
        onSearchChanged: () => setState(() {}),
        onToggleSearch: () => setState(() {
          _searching = !_searching;
          if (!_searching) _search.clear();
        }),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      child: Column(
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
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'Could not load messages: $e',
                      textAlign: TextAlign.center,
                      style: AppTypography.body,
                    ),
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
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.sm,
                          AppSpacing.gutter,
                          AppSpacing.md,
                        ),
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
          // The composer lives in the body, NOT in the Scaffold's bottom bar.
          // A bottomNavigationBar is pinned to the bottom of the scaffold and
          // is not lifted by the keyboard, so putting it there hid the very
          // field you were typing into. In the body it sits above the
          // shrinking message list and stays visible.
          if (canPost)
            _Composer(
              controller: _composer,
              sending: _sending,
              onSend: () => _send(chat, session),
              onAttach: () => _openTray(chat, session),
            )
          else
            const _ReadOnlyFooter(),
        ],
      ),
    );
  }

  /// The line under the conversation title.
  ///
  /// Not a presence indicator - this app has no presence system, and a green
  /// "Online" dot that is always on is a lie the user will eventually catch.
  /// It says what the conversation IS instead, which is the thing someone
  /// glancing at the header actually wants confirmed.
  String _presenceLine(Chat? chat) {
    if (chat == null) return 'Loading';
    return switch (chat.kind) {
      ChatKind.broadcast => 'Announcement - admin office only',
      ChatKind.direct => '${chat.members.length} participants',
    };
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

  /// Opens the attachment tray and does whatever was chosen.
  ///
  /// Everything except the ID Card row lands on the same file picker this
  /// screen always used - the tray is a choice of what to send, not a set of
  /// separate transports. The ID Card row is the one that is genuinely
  /// different: nothing is picked off the filesystem, a card is rendered.
  Future<void> _openTray(Chat? chat, SessionUser? session) async {
    if (chat == null || session == null) return;

    final AttachmentChoice? choice = await showAttachmentTray(context);
    if (choice == null || !mounted) return;

    if (choice == AttachmentChoice.idCard) {
      await _sendIdCard(chat, session);
      return;
    }
    await _attach(chat, session);
  }

  /// Renders an approved card and sends it into the conversation.
  ///
  /// It goes down the ordinary attachment path once rendered, which is what
  /// gives it the Storage-then-Firestore fallback for free. A card is an
  /// image like any other as far as transport is concerned; the only special
  /// part is where the bytes came from.
  Future<void> _sendIdCard(Chat chat, SessionUser session) async {
    final String? entryId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext c) =>
            SendIdCardScreen(recipientLabel: chat.title),
      ),
    );
    if (entryId == null || !mounted) return;

    final StudentEntry? entry = ref.read(entryByIdProvider(entryId));
    final SchoolConfig? config = ref.read(schoolConfigProvider).value;
    final CardTemplate? template = ref.read(activeTemplateProvider).value;

    if (entry == null || config == null || template == null) {
      _complain('The card is still loading. Give it a moment and try again.');
      return;
    }

    setState(() => _sending = true);
    try {
      final SharedCard card = await const CardShareService().render(
        entry: entry,
        config: config,
        template: template,
      );

      final String? problem = await ref
          .read(chatRepositoryProvider)
          .sendAttachment(
            chat: chat,
            senderId: session.uid,
            senderName: session.displayName.isEmpty
                ? session.email
                : session.displayName,
            body: _composer.text.trim(),
            file: card.file,
            fileName: card.fileName,
          );

      if (!mounted) return;
      if (problem != null) {
        _complain(problem);
      } else {
        _composer.clear();
      }
    } on Object catch (e) {
      if (!mounted) return;
      _complain(_describeAttachmentFailure(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: StatusColors.failed),
    );
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

/// The conversation header: a frosted pill carrying the avatar, the title,
/// what the conversation is, and search.
///
/// A pill rather than an AppBar because the page gradient has to run behind
/// it - that is the whole reason the glass reads as glass. It also means
/// search can take over the middle of the pill without the bar resizing.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.searching,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggleSearch,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final bool searching;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onToggleSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: GlassSurface(
        // Frosted for real: the message list scrolls up behind this.
        depth: GlassDepth.frosted,
        radius: BorderRadius.circular(AppRadius.sheet),
        fill: AppColors.glassFillStrong,
        shadows: AppShadows.card,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            _RoundAction(icon: Icons.arrow_back, onTap: onBack),
            const SizedBox(width: AppSpacing.sm),
            if (searching)
              Expanded(
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: (_) => onSearchChanged(),
                  style: AppTypography.input,
                  cursorColor: AppColors.chatDeep,
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Search messages',
                    hintStyle: AppTypography.placeholder,
                  ),
                ),
              )
            else ...<Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
                  ),
                ),
                child: Center(
                  child: Text(
                    _initial(title),
                    style: AppTypography.buttonSmall.copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTypography.section.copyWith(fontSize: 15.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.support,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            _RoundAction(
              icon: searching ? Icons.close : Icons.search,
              tooltip: searching ? 'Close search' : 'Search messages',
              onTap: onToggleSearch,
            ),
          ],
        ),
      ),
    );
  }

  static String _initial(String title) {
    final String t = title.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }
}

/// A circular tinted action inside the chat chrome.
///
/// Not GlassIconButton: that one is white-on-navy for the card pipeline, and
/// these have to sit inside an already-frosted pill without stacking a second
/// translucent layer on the first.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.rotate = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// Radians. Only the paperclip uses this.
  final double rotate;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: AppColors.chatDeep.withValues(alpha: 0.09),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Transform.rotate(
              angle: rotate,
              child: Icon(icon, size: 19, color: AppColors.chatDeep),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
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
    // Everyone except the sender has seen it.
    final bool readByAll = message.readBy.length >= memberCount;

    // An image fills its bubble edge to edge, so the bubble loses its padding
    // and the caption, timestamp and tick move inside on their own inset.
    final bool bleeds =
        message.hasAttachment && message.kind == MessageKind.image;

    return FadeSlideIn(
      // Slides in from the side it belongs to, which is the direction a
      // message actually travels. Zero stagger: in a chat every bubble is
      // already on screen, and a delay would make scrolling back feel laggy.
      offset: 6,
      duration: AppMotion.fast,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: GlassSurface(
            // Flat, not frosted. There are as many of these as there are
            // messages in the thread, and a BackdropFilter per bubble is the
            // single most reliable way to make a chat scroll badly.
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            // Outgoing in the green tint, incoming on near-white - the
            // arrangement people already read without being taught it.
            fill: isMine ? AppColors.chatMine : AppColors.chatTheirs,
            borderColor: isMine
                ? AppColors.chatAccent.withValues(alpha: 0.22)
                : AppColors.glassBorder,
            shadows: AppShadows.subtle,
            sheen: false,
            // The tail corner is the flat one, on the side the message came
            // from.
            radius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 5),
              bottomRight: Radius.circular(isMine ? 5 : 18),
            ),
            padding: bleeds
                ? const EdgeInsets.all(AppSpacing.xs)
                : const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 9,
                  ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                if (!isMine)
                  Padding(
                    padding: EdgeInsets.only(
                      left: bleeds ? AppSpacing.sm : 0,
                      top: bleeds ? AppSpacing.xs : 0,
                      bottom: 3,
                    ),
                    child: Text(
                      message.senderName,
                      style: AppTypography.badge.copyWith(
                        color: AppColors.chatDeep,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                if (message.hasAttachment) ...<Widget>[
                  _MessageAttachment(message: message),
                  if (message.body.isNotEmpty) const SizedBox(height: 6),
                ],
                if (message.body.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: bleeds ? AppSpacing.sm : 0,
                    ),
                    child: Text(
                      message.body,
                      style: AppTypography.body.copyWith(
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(
                    right: bleeds ? AppSpacing.sm : 0,
                    bottom: bleeds ? AppSpacing.xs : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        DateFormat('HH:mm').format(message.sentAt),
                        style: AppTypography.timestamp,
                      ),
                      if (isMine) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(
                          message.pending
                              ? Icons.schedule
                              : (readByAll ? Icons.done_all : Icons.done),
                          size: 14,
                          color: readByAll
                              ? AppColors.chatAccent
                              : AppColors.inkMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
        return const _AttachmentCard(
          label: 'Image unavailable',
          icon: Icons.broken_image_outlined,
        );
      }

      final Widget image = message.attachmentInline
          ? Image.memory(
              base64Decode(preview),
              width: 216,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                  const _AttachmentCard(
                    label: 'Image unavailable',
                    icon: Icons.broken_image_outlined,
                  ),
            )
          : Image.network(
              preview,
              width: 216,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                  const _AttachmentCard(
                    label: 'Image unavailable',
                    icon: Icons.broken_image_outlined,
                  ),
            );

      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Stack(
          children: <Widget>[
            PressableSurface(
              onTap: () => _openFullScreen(context, ref),
              child: image,
            ),
            // Save sits on the picture rather than under it. A card that has
            // been sent into a conversation is something the office is
            // expected to keep, and making them open it first to find out how
            // is a step for no reason.
            Positioned(
              right: 6,
              bottom: 6,
              child: _ImageAction(
                icon: Icons.download_outlined,
                tooltip: 'Save to device',
                onTap: () => _saveImage(context, ref),
              ),
            ),
          ],
        ),
      );
    }

    return PressableSurface(
      onTap: () => _openDocument(context, ref),
      child: _AttachmentCard(
        label: message.attachmentName ?? 'Document',
        icon: _documentIcon(message.attachmentName),
        subtitle: message.attachmentBytes == null
            ? 'Tap to open'
            : '${_formatBytes(message.attachmentBytes!)} - tap to open',
      ),
    );
  }

  static IconData _documentIcon(String? name) {
    final String ext = (name ?? '').toLowerCase();
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    if (ext.endsWith('.doc') || ext.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  /// Writes the full frame out and hands it to the platform.
  ///
  /// Deliberately the same route as [_openDocument] rather than a media-store
  /// write: saving into the gallery needs a storage permission this app does
  /// not ask for, and the system viewer this opens already offers Save and
  /// Share. So the file genuinely lands on disk and the OS owns what happens
  /// next, which is the correct division of labour.
  Future<void> _saveImage(BuildContext context, WidgetRef ref) async {
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
      // Falls back to the thumbnail rather than failing outright: a smaller
      // copy of the right picture beats an error message.
      final String base64Part = dataUri == null
          ? (message.attachmentThumb ?? '')
          : dataUri.substring(dataUri.indexOf(',') + 1);
      if (base64Part.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('That attachment is no longer available.'),
          ),
        );
        return;
      }

      final Uint8List bytes = base64Decode(base64Part);
      final Directory dir = await getTemporaryDirectory();
      final File out = File(
        '${dir.path}/${message.attachmentName ?? 'photo.jpg'}',
      );
      await out.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(out.path);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save that image: $e'),
          backgroundColor: StatusColors.failed,
        ),
      );
    }
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

/// A round action floating on an image bubble.
class _ImageAction extends StatelessWidget {
  const _ImageAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        // Opaque-ish dark rather than glass: this sits on photography, where
        // a translucent white disc disappears against a bright picture.
        color: const Color(0x8C0B2018),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: AppColors.onDark),
          ),
        ),
      ),
    );
  }
}

/// A non-image attachment: tinted file icon, name, size.
class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.label,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.chatDeep.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.chatDeep.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.chatDeep.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.chatDeep),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.support.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The composer: a floating frosted bar with the paperclip, the field and the
/// send button.
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: GlassSurface(
          // The thread scrolls under this, so it earns a real blur.
          depth: GlassDepth.frosted,
          radius: BorderRadius.circular(AppRadius.sheet),
          fill: AppColors.glassFillStrong,
          shadows: AppShadows.floating,
          sheen: false,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _RoundAction(
                // Tilted. Upright, the paperclip reads as a pin or a straw in
                // a row of small grey glyphs; the diagonal is the silhouette
                // an eye already searches for in a message composer.
                icon: Icons.attach_file,
                tooltip: 'Attach',
                onTap: sending ? () {} : onAttach,
                rotate: -0.72,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.input,
                    cursorColor: AppColors.chatDeep,
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Type a message',
                      hintStyle: AppTypography.placeholder,
                    ),
                    onSubmitted: (_) => sending ? null : onSend(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _SendButton(sending: sending, onTap: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});

  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
          ),
          boxShadow: sending ? null : AppShadows.glow(AppColors.chatDeep),
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: sending
              ? const Padding(
                  key: ValueKey<bool>(true),
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.onDark),
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  key: ValueKey<bool>(false),
                  size: 20,
                  color: AppColors.onDark,
                ),
        ),
      ),
    );
  }
}

class _BroadcastBanner extends StatelessWidget {
  const _BroadcastBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.sm,
      ),
      child: GlassSurface(
        radius: BorderRadius.circular(AppRadius.field),
        fill: AppColors.pendingTint.withValues(alpha: 0.85),
        borderColor: AppColors.pending.withValues(alpha: 0.22),
        shadows: AppShadows.subtle,
        sheen: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.campaign_outlined,
              size: 17,
              color: AppColors.pending,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Announcement - only the admin office can post here.',
                style: AppTypography.support.copyWith(color: AppColors.inkBody),
              ),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: GlassSurface(
          radius: BorderRadius.circular(AppRadius.sheet),
          fill: AppColors.glassFillStrong,
          shadows: AppShadows.subtle,
          sheen: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.lock_outline, size: 16, color: AppColors.inkMuted),
              SizedBox(width: AppSpacing.sm),
              Text(
                'You cannot reply to an announcement.',
                style: AppTypography.support,
              ),
            ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.statusTint(AppColors.chatAccent),
              ),
              child: Icon(
                searching ? Icons.search_off : Icons.forum_outlined,
                size: 34,
                color: AppColors.chatDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              searching ? 'No messages match' : 'No messages yet',
              style: AppTypography.title,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              searching ? 'Try a shorter search term.' : 'Send the first one.',
              style: AppTypography.support,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
