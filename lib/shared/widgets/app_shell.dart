import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_bottom_nav.dart';
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

  /// Lays the branch navigators out so they can cross-fade.
  ///
  /// Passed to `StatefulShellRoute.navigatorContainerBuilder`; see
  /// [_AnimatedBranchContainer] for why it is done this way rather than with
  /// an `AnimatedSwitcher`.
  static Widget animatedBranchContainer(
    BuildContext context,
    StatefulNavigationShell navigationShell,
    List<Widget> children,
  ) => _AnimatedBranchContainer(
    currentIndex: navigationShell.currentIndex,
    children: children,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unreadChats = ref.watch(unreadChatCountProvider);
    final int unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      // The bar floats over the content rather than sitting under it, so the
      // page gradient runs to the bottom of the screen behind the glass.
      // Every tab pads its own list by `AppSpacing.navClearance` so the last
      // row is not left underneath it.
      extendBody: true,
      backgroundColor: AppColors.canvas,
      body: navigationShell,
      bottomNavigationBar: GlassBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: (int index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on pops that branch back to its
          // root, which is what every other app does and what a user reaching
          // for "get me out of here" expects.
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: <GlassNavItem>[
          const GlassNavItem(
            icon: Icons.badge_outlined,
            activeIcon: Icons.badge,
            label: 'ID Cards',
          ),
          GlassNavItem(
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum,
            label: 'Chats',
            badge: unreadChats,
          ),
          GlassNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            badge: unreadNotifications,
          ),
        ],
      ),
    );
  }
}

/// Cross-fades between the three tabs instead of swapping them in one frame.
///
/// Every branch stays mounted and keeps its state - that is the entire reason
/// for a `StatefulShellRoute`, and an `AnimatedSwitcher` around the shell would
/// throw it away. Instead each branch navigator is laid out in a Stack and only
/// its opacity changes, which is the pattern go_router itself documents.
///
/// [TickerMode] is what stops the hidden branches costing anything: without it
/// every animation on all three tabs keeps running forever behind the one the
/// operator is looking at. [IgnorePointer] stops a fully transparent branch
/// swallowing taps meant for the visible one.
class _AnimatedBranchContainer extends StatelessWidget {
  const _AnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        for (int i = 0; i < children.length; i++)
          AnimatedOpacity(
            opacity: i == currentIndex ? 1 : 0,
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            child: TickerMode(
              enabled: i == currentIndex,
              child: IgnorePointer(
                ignoring: i != currentIndex,
                child: children[i],
              ),
            ),
          ),
      ],
    );
  }
}

/// A count bubble that animates in and out, so a message arriving while the
