import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/auth/presentation/login_screen.dart';
import 'package:flutter_id_card/shared/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The office moved to the web panel, and this app no longer has an admin in
/// it at all.
///
/// Deleting screens is the easy half. The half that bites is what happens to
/// somebody who already has an admin session on their phone, or who types an
/// admin address into the one sign-in box that is left: the code that used to
/// catch them is exactly the code that was removed. These are the tests for
/// the doors, not the rooms.
void main() {
  const SessionUser admin = SessionUser(
    uid: 'a1',
    email: 'admin@idcardx.app',
    role: UserRole.admin,
    displayName: 'System Admin',
  );

  const SessionUser teacher = SessionUser(
    uid: 'u1',
    email: 'teacher@demo.edu',
    role: UserRole.teacher,
    displayName: 'ATUL',
    schoolId: 'demo-school',
  );

  /// The real router, built from the real provider, for a given session.
  ///
  /// The container is kept and handed to `UncontrolledProviderScope` rather
  /// than thrown away: the screens the router builds are Riverpod consumers,
  /// and a `MaterialApp.router` with no scope above it fails on the first
  /// frame with "No ProviderScope found" long before any redirect runs.
  (GoRouter, ProviderContainer) routerFor(SessionUser? session) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _StubAuth(session)),
      ],
    );
    addTearDown(container.dispose);
    return (container.read(routerProvider), container);
  }

  Future<GoRouter> pumpApp(WidgetTester tester, SessionUser? session) async {
    final (GoRouter router, ProviderContainer container) = routerFor(session);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  group('The admin routes are gone', () {
    for (final String path in <String>[
      '/admin',
      '/admin/users',
      '/admin/requests',
      '/admin/broadcast',
      '/admin/audit',
      '/admin/reports',
      '/admin/schools/new',
    ]) {
      testWidgets('$path is not a route any more', (WidgetTester tester) async {
        // Not "is blocked" - genuinely absent. A redirect would leave the
        // screens in the binary and one bad condition away from reachable.
        final GoRouter router = await pumpApp(tester, teacher);

        router.go(path);
        await tester.pumpAndSettle();

        expect(
          find.text('Page not found'),
          findsOneWidget,
          reason: '$path still resolves to a screen',
        );
      });
    }
  });

  group('An admin session', () {
    testWidgets('is sent back to the login screen, not into the shell', (
      WidgetTester tester,
    ) async {
      // The case that actually happens: an admin signed in on a build that
      // had an admin section, upgrades, and launches. Their Firebase
      // credential is still valid and their profile is still cached, so
      // nothing in the sign-in path runs. Without this redirect they would
      // land on a home screen with no school and an empty card list - a
      // convincing imitation of an app that has lost their data.
      final GoRouter router = await pumpApp(tester, admin);

      router.go('/home');
      await tester.pumpAndSettle();

      expect(locationOf(router), LoginScreen.routePath);
    });

    testWidgets('cannot reach the message list either', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, admin);

      router.go('/messages');
      await tester.pumpAndSettle();

      expect(locationOf(router), LoginScreen.routePath);
    });

    testWidgets('while an operator still gets in', (WidgetTester tester) async {
      // The other half of the check. A redirect that turns everybody away
      // would pass both tests above and ship a dead app.
      final GoRouter router = await pumpApp(tester, teacher);

      router.go('/home');
      await tester.pumpAndSettle();

      expect(locationOf(router), '/home');
    });
  });

  group('The login screen', () {
    testWidgets('offers one way in, with no Admin tab', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _StubAuth(null)),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin'), findsNothing);
      expect(find.text('Sign in as Admin'), findsNothing);
      expect(find.text('Admin Email'), findsNothing);
      expect(find.text('School Name / Code'), findsOneWidget);
    });
  });
}

/// An auth controller that just reports a session, without Firebase.
class _StubAuth extends AuthController {
  _StubAuth(this._session);

  final SessionUser? _session;

  @override
  Future<SessionUser?> build() async => _session;
}
