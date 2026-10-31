import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/auth/presentation/email_code_screens.dart';
import 'package:flutter_id_card/features/auth/presentation/login_screen.dart';
import 'package:flutter_id_card/features/auth/presentation/profile_screen.dart';
import 'package:flutter_id_card/features/auth/presentation/splash_screen.dart';
import 'package:flutter_id_card/features/card_render/presentation/card_preview_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/data_entry_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/home_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/request_detail_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/saved_entries_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/submission_success_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/sync_status_screen.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_list_screen.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_screen.dart';
import 'package:flutter_id_card/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/awaiting_assignment_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/join_choice_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/parent_register_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/qr_scanner_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/register_screen.dart';
import 'package:flutter_id_card/features/photo_capture/presentation/photo_capture_screen.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/widgets/app_shell.dart';
import 'package:flutter_id_card/shared/widgets/coming_soon_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Wraps a screen in the app's own push transition.
///
/// Every pushed route goes through this. Without it go_router falls back to
/// the platform default, and the helper that defines how this app is supposed
/// to move between screens - [buildAppPageTransition] - was written but never
/// reachable, so every navigation in the app used Flutter's stock animation
/// while the design said otherwise.
///
/// The reverse is shorter than the forward: going back is a dismissal, and
/// matching the forward duration makes returning to a list feel slow.
Page<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.slow,
      reverseTransitionDuration: AppMotion.normal,
      transitionsBuilder: buildAppPageTransition,
    );

/// Routes that an unauthenticated visitor is allowed to sit on.
///
/// The join screens are public because that is where a teacher with no
/// account starts. Registering is the first thing they do, and a redirect to
/// /login would send somebody who has never had credentials to a form asking
/// for them.
const Set<String> _publicRoutes = <String>{
  '/',
  '/login',
  // Both halves of code sign-in. The second one matters: a person sitting on
  // the code screen is not signed in yet, and without it the redirect would
  // bounce them to the join screen the moment they arrived - taking the
  // address they just typed with it.
  EmailCodeRequestScreen.routePath,
  EmailCodeEntryScreen.routePath,
  JoinChoiceScreen.routePath,
  RegisterScreen.routePath,
  ParentRegisterScreen.routePath,
};

/// Routes a signed-in teacher may sit on while they still have no school.
///
/// Everything else redirects to the waiting screen. A teacher between
/// scanning a code and being approved has access to nothing, and letting
/// them reach the home screen would show an empty list that looks like a
/// broken app rather than a queue somebody has to act on.
const Set<String> _unassignedRoutes = <String>{
  JoinChoiceScreen.routePath,
  RegisterScreen.routePath,
  QrScannerScreen.routePath,
  AwaitingAssignmentScreen.routePath,
  '/profile',
};

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  // Bridges Riverpod's auth state into a Listenable so go_router re-evaluates
  // its redirect when someone signs in or out.
  final _AuthRefresh refresh = _AuthRefresh();
  ref.listen<AsyncValue<SessionUser?>>(
    authControllerProvider,
    (AsyncValue<SessionUser?>? _, AsyncValue<SessionUser?> _) => refresh.ping(),
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: SplashScreen.routePath,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<SessionUser?> auth = ref.read(authControllerProvider);
      final String location = state.matchedLocation;

      // The splash screen owns its own navigation (it waits out a minimum
      // display time), so never redirect away from it.
      if (location == SplashScreen.routePath) return null;

      // Mid-sign-in: leave the login form on screen so its spinner is visible.
      if (auth.isLoading) return null;

      final SessionUser? user = auth.value;

      if (user == null) {
        return _publicRoutes.contains(location)
            ? null
            : JoinChoiceScreen.routePath;
      }

      // An admin has no business in this app at all.
      //
      // The office works from the web panel: that is where schools are
      // created, cards are reviewed and announcements go out, and none of it
      // exists here any more. An admin account that reached the shell would
      // find a home screen with no school, an empty card list and a chat with
      // itself - a convincing imitation of a broken app. Signing out is the
      // honest answer, and `AuthController.signIn` explains why before it
      // gets here. This is the backstop for a session cached from an older
      // build, which would otherwise come back on launch.
      if (user.isAdmin) {
        return LoginScreen.routePath;
      }

      // A signed-in operator with no school has not been approved yet. The
      // matching rule is what actually withholds the data; this keeps them
      // off screens that would render as empty and look broken.
      if (!user.canEnterData) {
        return _unassignedRoutes.contains(location)
            ? null
            : AwaitingAssignmentScreen.routePath;
      }

      // Signed in, but still standing on a door. This is what carries
      // somebody out of the code screens the instant verification succeeds -
      // those screens deliberately do not navigate themselves, because where
      // a person belongs after signing in depends on their account, and this
      // is the one place that knows.
      if (location == LoginScreen.routePath ||
          location == EmailCodeRequestScreen.routePath ||
          location == EmailCodeEntryScreen.routePath ||
          location == JoinChoiceScreen.routePath ||
          location == RegisterScreen.routePath ||
          location == ParentRegisterScreen.routePath ||
          location == AwaitingAssignmentScreen.routePath) {
        return HomeScreen.routePath;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: SplashScreen.routePath,
        name: SplashScreen.routeName,
        builder: (BuildContext c, GoRouterState s) => const SplashScreen(),
      ),
      GoRoute(
        path: LoginScreen.routePath,
        name: LoginScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const LoginScreen()),
      ),
      GoRoute(
        path: EmailCodeRequestScreen.routePath,
        name: EmailCodeRequestScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const EmailCodeRequestScreen()),
      ),
      GoRoute(
        path: EmailCodeEntryScreen.routePath,
        name: EmailCodeEntryScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const EmailCodeEntryScreen()),
      ),
      GoRoute(
        path: JoinChoiceScreen.routePath,
        name: JoinChoiceScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const JoinChoiceScreen()),
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        name: RegisterScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const RegisterScreen()),
      ),
      GoRoute(
        path: ParentRegisterScreen.routePath,
        name: ParentRegisterScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const ParentRegisterScreen()),
      ),
      GoRoute(
        path: QrScannerScreen.routePath,
        name: QrScannerScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const QrScannerScreen()),
      ),
      GoRoute(
        path: AwaitingAssignmentScreen.routePath,
        name: AwaitingAssignmentScreen.routeName,
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const AwaitingAssignmentScreen()),
      ),
      // The operator's three tabs. Each branch keeps its own stack, so
      // switching to Chats and back does not reset a scrolled list.
      StatefulShellRoute(
        builder: (
          BuildContext c,
          GoRouterState s,
          StatefulNavigationShell shell,
        ) => AppShell(navigationShell: shell),
        // Not `.indexedStack`: that swaps tabs in a single frame, and tab
        // switching is the navigation an operator makes most. This keeps every
        // branch alive - the whole point of a stateful shell - and cross-fades
        // between them. See AppShell.animatedBranchContainer.
        navigatorContainerBuilder: AppShell.animatedBranchContainer,
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: HomeScreen.routePath,
                name: HomeScreen.routeName,
                builder: (BuildContext c, GoRouterState s) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/messages',
                builder: (BuildContext c, GoRouterState s) =>
                    const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (BuildContext c, GoRouterState s) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Everything below pushes over the shell: focused tasks where a
      // navigation bar underneath would invite a mis-tap that abandons
      // half-entered work.
      GoRoute(
        path: '/messages/:chatId',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, ChatScreen(chatId: s.pathParameters['chatId'] ?? '')),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/entry/new',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const DataEntryScreen()),
      ),
      GoRoute(
        path: '/entry/:id',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, DataEntryScreen(entryId: s.pathParameters['id'])),
      ),
      GoRoute(
        path: '/entries',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const SavedEntriesScreen()),
      ),
      GoRoute(
        path: '/submitted/:id',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, SubmissionSuccessScreen(entryId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/submissions/:id',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, RequestDetailScreen(entryId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/sync',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, const SyncStatusScreen()),
      ),
      GoRoute(
        path: '/photo',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, PhotoCaptureScreen(existingPath: s.extra as String?)),
      ),
      GoRoute(
        path: '/preview/:id',
        pageBuilder: (BuildContext c, GoRouterState s) =>
            _page(s, CardPreviewScreen(entryId: s.pathParameters['id'] ?? '')),
      ),

    ],
    // A 404 in a shipped app is a bug, not a user error, so it says what it
    // knows and offers the one way out rather than dead-ending.
    errorBuilder: (BuildContext context, GoRouterState state) =>
        ComingSoonScreen(
          title: 'Page not found',
          phase: 'NO ROUTE',
          description:
              'There is no screen at ${state.uri}. Tell the office if a '
              'button in the app brought you here.',
        ),
  );
});

class _AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
