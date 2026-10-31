import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/application/otp_controller.dart';
import 'package:flutter_id_card/features/auth/data/otp_repository.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/auth/presentation/email_code_screens.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Signing in with a code emailed to you.
///
/// The security of this lives in the Cloud Functions and is tested there
/// (functions/src/otp.test.ts) - expiry, the guess ceiling, the rate limit,
/// the hashing. What is tested here is the half the person actually touches:
/// that a wrong code says so without losing what they typed, that Resend
/// stays shut for as long as the server said, and that a success does not
/// navigate anywhere by itself.
///
/// That last one is easy to get wrong in a way no manual test would catch.
/// These screens must NOT route to /home: a teacher the office has not
/// approved yet belongs on the waiting screen, and only the router knows
/// that. A `context.go('/home')` here would look right on the one account a
/// developer happens to test with.
void main() {
  /// A container the test owns, with the Cloud Functions faked out.
  ///
  /// Built here rather than with `ProviderScope(overrides: ...)` because
  /// Riverpod 3 does not export `Override`, so a helper cannot name the type
  /// of an override list. Holding the container is better anyway - these
  /// tests read the controller directly to check the countdown.
  ProviderContainer containerWith(_FakeOtp fake, {bool stubAuth = false}) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        otpRepositoryProvider.overrideWithValue(fake),
        if (stubAuth) authControllerProvider.overrideWith(_StubAuth.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Pumps the real screens behind a real router.
  ///
  /// A bare `MaterialApp` is not enough: the first screen moves to the second
  /// with `context.push`, which throws "No GoRouter found in context". Giving
  /// the test a router also means the navigation itself can be asserted
  /// rather than assumed.
  Future<GoRouter> pumpFlow(
    WidgetTester tester,
    ProviderContainer container, {
    String at = EmailCodeRequestScreen.routePath,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: at,
      routes: <RouteBase>[
        GoRoute(
          path: EmailCodeRequestScreen.routePath,
          builder: (_, _) => const EmailCodeRequestScreen(),
        ),
        GoRoute(
          path: EmailCodeEntryScreen.routePath,
          builder: (_, _) => const EmailCodeEntryScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The app's own theme, so the test sees the button sizes and
        // text styles the person will.
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Runs the resend countdown to zero so no periodic timer outlives the test.
  ///
  /// The binding checks for pending timers at the end of the test BODY, which
  /// is before any tearDown runs - so disposing the container there is too
  /// late. Draining the clock is simpler than reaching in to cancel, and it
  /// exercises the countdown's own cancellation into the bargain.
  Future<void> drainCountdown(WidgetTester tester, Duration cooldown) async {
    for (int i = 0; i <= cooldown.inSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  group('Asking for a code', () {
    testWidgets('refuses an address that is obviously not one', (
      WidgetTester tester,
    ) async {
      // Caught before the call, so an obvious typo does not spend one of the
      // five sends the address is allowed in an hour.
      final _FakeOtp fake = _FakeOtp();
      await pumpFlow(tester, containerWith(fake));

      await tester.enterText(find.byType(TextFormField), 'not-an-address');
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(fake.sends, isEmpty, reason: 'nothing should have been sent');
    });

    testWidgets('normalises the address, then moves to the code screen', (
      WidgetTester tester,
    ) async {
      // The server files the record under a hash of the normalised address.
      // Sending "  Teacher@Example.COM " unchanged would store the code under
      // a different key than the verify step computes, and every code would
      // come back wrong.
      final _FakeOtp fake = _FakeOtp(cooldown: const Duration(seconds: 1));
      await pumpFlow(tester, containerWith(fake));

      await tester.enterText(
        find.byType(TextFormField),
        '  Teacher@Example.COM ',
      );
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      expect(fake.sends, <String>['teacher@example.com']);
      expect(find.byType(EmailCodeEntryScreen), findsOneWidget);

      await drainCountdown(tester, const Duration(seconds: 1));
    });

    testWidgets('shows the server message when it refuses, and stays put', (
      WidgetTester tester,
    ) async {
      final _FakeOtp fake = _FakeOtp(
        onRequest: () => throw const AuthFailure(
          'Wait 42 seconds before asking for another code.',
        ),
      );
      await pumpFlow(tester, containerWith(fake));

      await tester.enterText(find.byType(TextFormField), 'a@b.cc');
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      // The server's own wording, with the real number of seconds in it -
      // more useful than anything the app could invent.
      expect(
        find.text('Wait 42 seconds before asking for another code.'),
        findsOneWidget,
      );
      expect(find.byType(EmailCodeEntryScreen), findsNothing);
    });
  });

  group('The resend timer', () {
    test('counts down from the number the SERVER gave', () async {
      // Not from a constant in the app. The limit that matters is enforced
      // in sendOtp; a button that goes live early only invites a refusal.
      final ProviderContainer container = containerWith(
        _FakeOtp(cooldown: const Duration(seconds: 37)),
      );

      await container.read(otpControllerProvider.notifier).requestCode('a@b.cc');

      expect(container.read(otpControllerProvider).resendIn.inSeconds, 37);
      expect(container.read(otpControllerProvider).canResend, isFalse);
    });

    test('a second tap during the wait sends nothing', () async {
      // The cooldown is enforced on the server, but a button that fires
      // anyway spends a round trip and comes back with a refusal, which
      // reads as the app being broken.
      final _FakeOtp fake = _FakeOtp(cooldown: const Duration(seconds: 60));
      final ProviderContainer container = containerWith(fake);
      final OtpController controller = container.read(
        otpControllerProvider.notifier,
      );

      await controller.requestCode('a@b.cc');
      expect(fake.sends.length, 1);

      await controller.resend();
      expect(fake.sends.length, 1, reason: 'still inside the cooldown');
    });

    testWidgets('states the wait, then opens the button at zero', (
      WidgetTester tester,
    ) async {
      // A disabled button with no explanation reads as broken. The seconds
      // are the message.
      const Duration cooldown = Duration(seconds: 2);
      final ProviderContainer container = containerWith(
        _FakeOtp(cooldown: cooldown),
      );
      await pumpFlow(tester, container, at: EmailCodeEntryScreen.routePath);

      await container.read(otpControllerProvider.notifier).requestCode('a@b.cc');
      await tester.pump();

      expect(find.textContaining('Send another in'), findsOneWidget);
      expect(find.text('Send another'), findsNothing);

      await drainCountdown(tester, cooldown);

      expect(find.text('Send another'), findsOneWidget);
    });
  });

  group('Entering the code', () {
    test('rejects a short code without calling the server', () async {
      final _FakeOtp fake = _FakeOtp();
      final ProviderContainer container = containerWith(fake);

      final bool ok = await container
          .read(otpControllerProvider.notifier)
          .submitCode('123');

      expect(ok, isFalse);
      expect(fake.verifies, isEmpty);
      expect(
        container.read(otpControllerProvider).error,
        'Enter the six digits from the email',
      );
    });

    testWidgets('keeps the typed code on screen when it is wrong', (
      WidgetTester tester,
    ) async {
      // Clearing the field on a wrong code makes somebody who mistyped one
      // digit retype all six, and burns an attempt doing it.
      final _FakeOtp fake = _FakeOtp(
        onVerify: () =>
            throw const AuthFailure('That code is not right. 4 tries left.'),
      );
      await pumpFlow(
        tester,
        containerWith(fake),
        at: EmailCodeEntryScreen.routePath,
      );

      await tester.enterText(find.byType(TextFormField), '000111');
      await tester.pumpAndSettle();

      expect(find.text('That code is not right. 4 tries left.'), findsOneWidget);
      expect(find.text('000111'), findsOneWidget);
    });

    testWidgets('submits itself on the sixth digit', (
      WidgetTester tester,
    ) async {
      // Six characters then hunting for a button means, on a phone, hunting
      // behind the keyboard.
      final _FakeOtp fake = _FakeOtp();
      await pumpFlow(
        tester,
        containerWith(fake, stubAuth: true),
        at: EmailCodeEntryScreen.routePath,
      );

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.pumpAndSettle();
      expect(fake.verifies, isEmpty, reason: 'five digits is not a code yet');

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pumpAndSettle();
      expect(fake.verifies, <String>['123456']);
    });

    testWidgets('does not navigate on success - the router decides', (
      WidgetTester tester,
    ) async {
      // A teacher the office has not approved belongs on the waiting screen,
      // not /home. Only the real redirect knows that, so these screens must
      // stay out of it.
      final _FakeOtp fake = _FakeOtp();
      final GoRouter router = await pumpFlow(
        tester,
        containerWith(fake, stubAuth: true),
        at: EmailCodeEntryScreen.routePath,
      );

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        EmailCodeEntryScreen.routePath,
        reason: 'the screen stays put; the redirect moves the person',
      );
    });

    testWidgets('only the digits can be typed', (WidgetTester tester) async {
      // A pasted "123 456" or a code with a stray letter would otherwise be
      // sent as-is and refused by the server for the wrong reason.
      final _FakeOtp fake = _FakeOtp();
      await pumpFlow(
        tester,
        containerWith(fake, stubAuth: true),
        at: EmailCodeEntryScreen.routePath,
      );

      await tester.enterText(find.byType(TextFormField), '12a 34b56789');
      await tester.pumpAndSettle();

      expect(fake.verifies, <String>['123456']);
    });
  });
}

/// Stands in for the Cloud Functions, recording what it was asked to do.
class _FakeOtp implements OtpRepository {
  _FakeOtp({
    this.cooldown = const Duration(seconds: 60),
    this.onRequest,
    this.onVerify,
  });

  final Duration cooldown;
  final void Function()? onRequest;
  final void Function()? onVerify;

  final List<String> sends = <String>[];
  final List<String> verifies = <String>[];

  @override
  bool get isBackendAvailable => true;

  @override
  Future<Duration> requestCode(String email) async {
    onRequest?.call();
    sends.add(email);
    return cooldown;
  }

  @override
  Future<void> submitCode({required String email, required String code}) async {
    onVerify?.call();
    verifies.add(code);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reports a signed-in operator without touching Firebase.
class _StubAuth extends AuthController {
  @override
  Future<SessionUser?> build() async => null;

  @override
  Future<bool> completeCodeSignIn() async {
    state = const AsyncValue<SessionUser?>.data(
      SessionUser(
        uid: 'u1',
        email: 'teacher@demo.edu',
        role: UserRole.teacher,
        schoolId: 'demo-school',
      ),
    );
    return true;
  }
}
