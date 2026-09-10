import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The three-tab shell an operator lives in: ID Cards, Chats, Profile.
///
/// Backed by a `StatefulShellRoute`, so each tab keeps its own navigation stack
/// and scroll position - switching to Chats and back does not throw away a
/// half-scrolled submissions list.
///
/// Detail screens (the form, a submission, a conversation) are top-level routes
/// that push *over* this shell rather than inside a branch. They are focused
/// tasks; leaving a navigation bar under them invites a mis-tap that abandons
/// half-entered work.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unreadChats = ref.watch(unreadChatCountProvider);
    final int unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on pops that branch back to its
          // root, which is what every other app does and what a user reaching
          // for "get me out of here" expects.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.badge_outlined),
            selectedIcon: const Icon(Icons.badge),
            label: 'ID Cards',
            // The badge here counts work the operator must fix, which is the
            // only thing on this tab that cannot wait.
            tooltip: unreadNotifications == 0
                ? 'ID Cards'
                : '$unreadNotifications need attention',
          ),
          NavigationDestination(
            icon: _Badged(
              count: unreadChats,
              child: const Icon(Icons.forum_outlined),
            ),
            selectedIcon: _Badged(
              count: unreadChats,
              child: const Icon(Icons.forum),
            ),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: _Badged(
              count: unreadNotifications,
              child: const Icon(Icons.person_outline),
            ),
            selectedIcon: _Badged(
              count: unreadNotifications,
              child: const Icon(Icons.person),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// A count bubble that animates in and out, so a message arriving while the
/// operator is looking at the bar is visible rather than a silent swap.
class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          right: -6,
          top: -4,
          child: AnimatedScale(
            scale: count > 0 ? 1 : 0,
            duration: AppMotion.normal,
            curve: AppMotion.emphasized,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
