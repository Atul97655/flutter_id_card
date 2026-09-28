import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
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
    final bool isAdmin = session?.isAdmin ?? false;

    return GlassScaffold(
      backdrop: GlassBackdrop.chat,
      header: GlassHeader(
        title: 'Messages',
        subtitle: isAdmin ? 'Every school you talk to' : 'The admin office',
      ),
      floatingActionButton: isAdmin
          ? _NewChatButton(
              onTap: () => _startConversation(context, ref, session!),
            )
          : null,
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
                    ? _EmptyState(isAdmin: isAdmin)
                    : ListView.separated(
                        key: ValueKey<int>(list.length),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          0,
                          AppSpacing.gutter,
                          // Clears both the floating navigation bar and the
                          // admin's New button.
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

    // Look the school's operators up so they are actual members of the chat.
    // Without this the conversation exists but is invisible to the very person
    // it is addressed to, because the security rules gate reads on membership.
    final List<String> operators = await ref
        .read(authRepositoryProvider)
        .operatorUidsForSchool(school.id);

    final Chat chat = await ref
        .read(chatRepositoryProvider)
        .createChat(
          title: school.name,
          members: <String>{admin.uid, ...operators}.toList(),
          schoolId: school.id,
        );

    if (!context.mounted) return;

    // Say so plainly rather than letting the admin type into a void.
    if (operators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No operator account is linked to ${school.name} yet, so nobody '
            'will see this conversation until one signs in.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }

    unawaited(context.push('/messages/${chat.id}'));
  }
}

/// The action that starts a conversation.
///
/// A gradient pill rather than a Material FAB: the FAB brings its own
/// elevation and circle, both of which fight the glass, and this carries a
/// word because "which button starts a chat" is not obvious from a plus sign.
class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifted clear of the floating navigation bar underneath it.
      padding: const EdgeInsets.only(bottom: AppSpacing.navClearance - 28),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.glow(AppColors.chatDeep),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.add_comment_outlined,
                size: 19,
                color: AppColors.onDark,
              ),
              SizedBox(width: AppSpacing.sm),
              Text('New', style: AppTypography.button),
            ],
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
  const _EmptyState({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return _Placeholder(
      icon: Icons.forum_outlined,
      title: 'No conversations yet',
      body: isAdmin
          ? 'Start one with a school using the button below.'
          : 'The admin office will start a conversation when they need to '
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
