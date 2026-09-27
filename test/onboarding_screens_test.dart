/// The onboarding screens, as a teacher reads them.
///
/// These are the first four screens anybody sees, and three of them exist to
/// say something rather than to do something. So what is asserted here is
/// mostly the wording: that the entry screen names who issues accounts, and
/// that the waiting screen says who resolves the wait. A screen that renders
/// but says the wrong thing is the failure mode these are built against.
library;

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/onboarding/application/join_providers.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_id_card/features/onboarding/presentation/awaiting_assignment_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/join_choice_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Override` is not exported from flutter_riverpod 3, so the override list
/// can never be given a type of its own - it only type-checks through
/// downward inference from `ProviderScope.overrides`. Every helper here
/// therefore builds the whole scope rather than passing a list around.
Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  group('Screen 15 - sign in or scan', () {
    testWidgets('offers both ways in', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const JoinChoiceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with my details'), findsOneWidget);
      expect(find.text('Scan my school QR code'), findsOneWidget);
    });

    // The third case: a teacher holding neither. Naming who issues both is
    // what stops this screen producing a phone call to the office.
    testWidgets('says where accounts and codes come from', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const JoinChoiceScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ask your school office'), findsOneWidget);
      expect(find.textContaining('issued by them'), findsOneWidget);
    });

    testWidgets('describes the job in one sentence', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const JoinChoiceScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('That is the whole job'), findsOneWidget);
    });
  });

  group('Screen 18 - awaiting assignment', () {
    const SessionUser waiting = SessionUser(
      uid: 'uid-ramesh',
      email: 'ramesh@stjohn.edu',
      role: UserRole.teacher,
      displayName: 'RAMESH PATIL',
    );

    Widget waitingScreen(JoinState state) => ProviderScope(
      overrides: [
        currentSessionProvider.overrideWithValue(waiting),
        joinStateProvider.overrideWith(
          (Ref ref) => Stream<JoinState>.value(state),
        ),
      ],
      child: const MaterialApp(home: AwaitingAssignmentScreen()),
    );

    testWidgets('names the school it connected to', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        waitingScreen(
          const JoinState(
            status: JoinStatus.pending,
            schoolId: 'SJS-2026-0041',
            schoolName: 'ST. JOHN SAMARITAN',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connected to'), findsOneWidget);
      expect(find.text('ST. JOHN SAMARITAN'), findsOneWidget);
    });

    // The reason this screen exists at all.
    testWidgets('says who resolves the wait, in order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        waitingScreen(
          const JoinState(status: JoinStatus.pending, schoolId: 'SJS'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What happens next'), findsOneWidget);
      expect(
        find.textContaining('Your school office sees your name'),
        findsOneWidget,
      );
      expect(find.textContaining('They assign you a class'), findsOneWidget);
    });

    testWidgets('is not dressed up as an error', (WidgetTester tester) async {
      await tester.pumpWidget(
        waitingScreen(
          const JoinState(status: JoinStatus.pending, schoolId: 'SJS'),
        ),
      );
      await tester.pumpAndSettle();

      // Waiting here is the system working as designed. Error language would
      // send a teacher to the office to report a fault that does not exist.
      expect(find.textContaining('Error'), findsNothing);
      expect(find.textContaining('failed'), findsNothing);
      expect(find.textContaining('Something went wrong'), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('gives the teacher something to press', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        waitingScreen(
          const JoinState(status: JoinStatus.pending, schoolId: 'SJS'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Check again'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    // So a teacher ringing the office can say which account to look for.
    testWidgets('shows which account is waiting', (WidgetTester tester) async {
      await tester.pumpWidget(
        waitingScreen(
          const JoinState(status: JoinStatus.pending, schoolId: 'SJS'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting as ramesh@stjohn.edu'), findsOneWidget);
    });

    testWidgets('falls back gracefully when the school has no name yet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        waitingScreen(
          const JoinState(status: JoinStatus.pending, schoolId: 'SJS'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('your school'), findsOneWidget);
    });
  });
}
