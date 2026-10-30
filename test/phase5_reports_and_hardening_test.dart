import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/widgets/offline_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5: Offline Banner Widget', () {
    testWidgets('shows warning when device is offline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOfflineProvider.overrideWithValue(true)],
          child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
        ),
      );

      expect(find.textContaining('Working offline'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('remains hidden when device is online', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOfflineProvider.overrideWithValue(false)],
          child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
        ),
      );

      expect(find.textContaining('Working offline'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });
  });

  group('Phase 5: Multi-Tenant Security & Tenant Isolation', () {
    test('an operator cannot submit into another school', () {
      const SessionUser operator = SessionUser(
        uid: 'op-1',
        role: UserRole.school,
        schoolId: 'sch-alpha',
        email: 'operator@alpha.edu',
      );

      // Mirrors the guard in data_entry_screen.dart. It used to carry an
      // admin bypass; that went with the admin section, because no admin can
      // sign into this app any more and a bypass nothing can take is a hole
      // waiting for the next role to fall through.
      bool isAuthorized(SessionUser user, String targetSchoolId) {
        if (user.schoolId != null && user.schoolId != targetSchoolId) {
          return false;
        }
        return true;
      }

      expect(isAuthorized(operator, 'sch-alpha'), isTrue);
      expect(isAuthorized(operator, 'sch-beta'), isFalse);
    });

    test('a parent has no school, so no school is foreign to them', () {
      // A parent submits into whichever school they picked. The rules are
      // what hold them to their own cards afterwards - see the `isParent`
      // create rule in firestore.rules - not this client-side guard.
      const SessionUser parent = SessionUser(
        uid: 'p-1',
        role: UserRole.parent,
        email: 'parent@example.com',
      );

      expect(parent.schoolId, isNull);
      expect(parent.canEnterData, isTrue);
    });
  });
}
