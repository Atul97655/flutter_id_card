import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/admin_users_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/audit_log_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/export_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/print_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/reports_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/requests_queue_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/school_detail_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/school_settings_screen.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
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
import 'package:flutter_id_card/features/messaging/presentation/broadcast_screen.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_list_screen.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_screen.dart';
import 'package:flutter_id_card/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_id_card/features/photo_capture/presentation/photo_capture_screen.dart';
import 'package:flutter_id_card/shared/widgets/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Routes that an unauthenticated visitor is allowed to sit on.
const Set<String> _publicRoutes = <String>{'/', '/login'};

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
        return _publicRoutes.contains(location) ? null : LoginScreen.routePath;
      }
      if (location == LoginScreen.routePath) {
        return user.isAdmin ? '/admin' : HomeScreen.routePath;
      }
      // Admin-only areas. The matching server-side rule is what actually
      // protects the data; this just keeps the UI honest.
      if (location.startsWith('/admin') && !user.isAdmin) {
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
        builder: (BuildContext c, GoRouterState s) => const LoginScreen(),
      ),
      // The operator's three tabs. Each branch keeps its own stack, so
      // switching to Chats and back does not reset a scrolled list.
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext c,
          GoRouterState s,
          StatefulNavigationShell shell,
        ) =>
            AppShell(navigationShell: shell),
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
        builder: (BuildContext c, GoRouterState s) => ChatScreen(
          chatId: s.pathParameters['chatId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext c, GoRouterState s) =>
            const NotificationsScreen(),
      ),
      GoRoute(
        path: '/entry/new',
        builder: (BuildContext c, GoRouterState s) => const DataEntryScreen(),
      ),
      GoRoute(
        path: '/entry/:id',
        builder: (BuildContext c, GoRouterState s) =>
            DataEntryScreen(entryId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/entries',
        builder: (BuildContext c, GoRouterState s) => const SavedEntriesScreen(),
      ),
      GoRoute(
        path: '/submitted/:id',
        builder: (BuildContext c, GoRouterState s) => SubmissionSuccessScreen(
          entryId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/submissions/:id',
        builder: (BuildContext c, GoRouterState s) => RequestDetailScreen(
          entryId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/sync',
        builder: (BuildContext c, GoRouterState s) => const SyncStatusScreen(),
      ),
      GoRoute(
        path: '/photo',
        builder: (BuildContext c, GoRouterState s) => PhotoCaptureScreen(
          existingPath: s.extra as String?,
        ),
      ),
      GoRoute(
        path: '/preview/:id',
        builder: (BuildContext c, GoRouterState s) => CardPreviewScreen(
          entryId: s.pathParameters['id'] ?? '',
        ),
      ),

      // --- admin (role-gated by the redirect above) ---------------------
      GoRoute(
        path: '/admin',
        builder: (BuildContext c, GoRouterState s) => const AdminDashboardScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'users',
            builder: (BuildContext c, GoRouterState s) =>
                const AdminUsersScreen(),
          ),
          GoRoute(
            // Literal 'new' is declared before the ':schoolId' pattern so it is
            // matched as the create route rather than as a school whose id
            // happens to be "new".
            path: 'schools/new',
            builder: (BuildContext c, GoRouterState s) =>
                const SchoolSettingsScreen(),
          ),
          GoRoute(
            path: 'schools/:schoolId',
            builder: (BuildContext c, GoRouterState s) => SchoolDetailScreen(
              schoolId: s.pathParameters['schoolId'] ?? '',
            ),
            routes: <RouteBase>[
              GoRoute(
                path: 'settings',
                builder: (BuildContext c, GoRouterState s) => SchoolSettingsScreen(
                  schoolId: s.pathParameters['schoolId'],
                ),
              ),
              GoRoute(
                path: 'print',
                builder: (BuildContext c, GoRouterState s) => PrintScreen(
                  schoolId: s.pathParameters['schoolId'] ?? '',
                ),
              ),
              GoRoute(
                path: 'export',
                builder: (BuildContext c, GoRouterState s) => ExportScreen(
                  schoolId: s.pathParameters['schoolId'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'requests',
            builder: (BuildContext c, GoRouterState s) =>
                const RequestsQueueScreen(),
          ),
          GoRoute(
            path: 'broadcast',
            builder: (BuildContext c, GoRouterState s) =>
                const BroadcastScreen(),
          ),
          GoRoute(
            path: 'audit',
            builder: (BuildContext c, GoRouterState s) =>
                const AuditLogScreen(),
          ),
          GoRoute(
            path: 'reports',
            builder: (BuildContext c, GoRouterState s) =>
                const ReportsScreen(),
          ),
          GoRoute(
            path: 'export/:schoolId',
            builder: (BuildContext c, GoRouterState s) => ExportScreen(
              schoolId: s.pathParameters['schoolId'] ?? '',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(child: Text('No route for ${state.uri}')),
    ),
  );
});

class _AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
