import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// List of conversations. Admins can start new ones; operators only reply to
/// what the admin office opened, which keeps the chat list bounded and stops
/// schools messaging each other.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  static const String routePath = '/messages';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(currentSessionProvider);
    final AsyncValue<List<Chat>> chats = ref.watch(myChatsProvider);
    final bool isAdmin = session?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _startConversation(context, ref, session!),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New'),
            )
          : null,
      body: !FirebaseBootstrap.instance.isReady
          ? const _OfflineNotice()
          : chats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text('Could not load conversations: $e'),
                ),
              ),
              data: (List<Chat> list) => list.isEmpty
                  ? _EmptyState(isAdmin: isAdmin)
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.gutter),
                      itemCount: list.length,
                      separatorBuilder: (BuildContext _, int _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int i) => _ChatTile(
                        chat: list[i],
                        uid: session?.uid ?? '',
                        onTap: () => context.push('/messages/${list[i].id}'),
                      ),
                    ),
            ),
    );
  }

  /// Admin picks a school; the conversation is created with both parties as
  /// members so the security rules admit them both.
  Future<void> _startConversation(
    BuildContext context,
    WidgetRef ref,
    SessionUser admin,
  ) async {
    final List<SchoolConfig> schools =
        ref.read(allSchoolsProvider).value ?? const <SchoolConfig>[];

    if (schools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No schools yet - add one before starting a chat.'),
        ),
      );
      return;
    }

    final SchoolConfig? school = await showModalBottomSheet<SchoolConfig>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const ListTile(
              title: Text(
                'Start a conversation with',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            for (final SchoolConfig s in schools)
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(s.name),
                subtitle: Text(s.id),
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );

    if (school == null || !context.mounted) return;

    // The operator's UID is not known here - the admin panel does not read the
    // users collection by school. Membership is seeded with the admin, and the
    // operator is added when their account is linked. Until then the chat is
    // visible to admins only, which is the safe direction.
    final Chat chat = await ref.read(chatRepositoryProvider).createChat(
          title: school.name,
          members: <String>[admin.uid],
          schoolId: school.id,
        );

    if (context.mounted) unawaited(context.push('/messages/${chat.id}'));
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.uid, required this.onTap});

  final Chat chat;
  final String uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unread = chat.isUnreadFor(uid);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: chat.kind == ChatKind.broadcast
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
          child: Icon(
            chat.kind == ChatKind.broadcast
                ? Icons.campaign_outlined
                : Icons.forum_outlined,
            size: 20,
            color: chat.kind == ChatKind.broadcast
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          chat.title,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          chat.lastMessage.isEmpty ? 'No messages yet' : chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            color: unread
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (chat.lastMessageAt != null)
              Text(
                _relative(chat.lastMessageAt!),
                style: const TextStyle(fontSize: 11),
              ),
            if (unread) ...<Widget>[
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime at) {
    final Duration age = DateTime.now().difference(at);
    if (age.inMinutes < 1) return 'now';
    if (age.inHours < 1) return '${age.inMinutes}m';
    if (age.inDays < 1) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    return DateFormat('dd MMM').format(at);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.forum_outlined, size: 52, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text('No conversations yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? 'Start one with a school using the button below.'
                  : 'The admin office will start a conversation when they need '
                      'to reach you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text('Messaging needs a connection', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Unlike card entry, chat is not stored offline - messages live on '
              'the server. Card capture keeps working without a connection.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
