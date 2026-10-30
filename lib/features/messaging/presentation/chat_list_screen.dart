import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
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

    return GlassScaffold(
      backdrop: GlassBackdrop.chat,
      header: const GlassHeader(
        title: 'Messages',
        subtitle: 'The admin office',
      ),
      // No "new conversation" button. Starting one was the admin's, and the
      // admin works from the web panel now. An operator has exactly one
      // conversation - with the office - and the office opens it.
      child: SmoothSwitcher(
        alignment: Alignment.center,
        child: !FirebaseBootstrap.instance.isReady
            ? const _OfflineNotice()
            : chats.when(
                loading: () => const Center(
                  key: ValueKey<String>('loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (Object e, StackTrace s) => Center(
                  key: const ValueKey<String>('error'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'Could not load conversations: $e',
                      textAlign: TextAlign.center,
                      style: AppTypography.body,
                    ),
                  ),
                ),
                data: (List<Chat> list) => list.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        key: ValueKey<int>(list.length),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          0,
                          AppSpacing.gutter,
                          AppSpacing.navClearance + AppSpacing.xl,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (BuildContext _, int _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int i) =>
                            FadeSlideIn(
                              index: i,
                              child: _ChatTile(
                                chat: list[i],
                                uid: session?.uid ?? '',
                                onTap: () =>
                                    context.push('/messages/${list[i].id}'),
                              ),
                            ),
                      ),
              ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.uid, required this.onTap});

  final Chat chat;
  final String uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool unread = chat.isUnreadFor(uid);
    final bool announcement = chat.kind == ChatKind.broadcast;
    final Color tint = announcement ? AppColors.pending : AppColors.chatAccent;

    return GlassSurface(
      radius: AppRadius.cardR,
      // An unread row is a touch more solid. That is enough to pick it out of
      // a column of glass without a coloured background shouting about it.
      fill: unread ? AppColors.glassFillStrong : AppColors.glassFill,
      shadows: unread ? AppShadows.card : AppShadows.subtle,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.statusTint(tint),
            ),
            child: Icon(
              announcement ? Icons.campaign_outlined : Icons.forum_outlined,
              size: 21,
              color: announcement ? AppColors.pending : AppColors.chatDeep,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  chat.title,
                  style: AppTypography.section.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  chat.lastMessage.isEmpty
                      ? 'No messages yet'
                      : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.support.copyWith(
                    color: unread ? AppColors.inkBody : AppColors.inkMuted,
                    fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (chat.lastMessageAt != null)
                Text(
                  _relative(chat.lastMessageAt!),
                  style: AppTypography.timestamp,
                ),
              // Scales rather than appears: a dot arriving in a row the
              // operator is already looking at is the one moment in this list
              // where motion is carrying information.
              AnimatedScale(
                scale: unread ? 1 : 0,
                duration: AppMotion.normal,
                curve: AppMotion.emphasized,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.chatAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
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

/// A full-page explanation with an illustration-weight icon.
///
/// Shared by both empty states here so that "nothing yet" and "no connection"
/// cannot drift into looking like different kinds of problem.
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.body,
    this.tint = AppColors.chatAccent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.statusTint(tint),
              ),
              child: Icon(icon, size: 38, color: tint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTypography.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.support,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(
      icon: Icons.forum_outlined,
      title: 'No conversations yet',
      body:
          'The admin office will start a conversation when they need to '
          'reach you.',
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(
      icon: Icons.cloud_off,
      title: 'Messaging needs a connection',
      body:
          'Unlike card entry, chat is not stored offline - messages live on '
          'the server. Card capture keeps working without a connection.',
      tint: AppColors.info,
    );
  }
}
