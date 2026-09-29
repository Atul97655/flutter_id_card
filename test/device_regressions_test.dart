import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/auth/presentation/profile_screen.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_screen.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three regressions found on a real device after the glass redesign, none of
/// which any existing test would have caught.
///
/// All three are the same class of mistake: a widget that looks correct in
/// isolation and is wrong in the layout it actually ships inside. That is
/// precisely what the component tests could not see, because they pump each
/// widget on its own.
void main() {
  const SessionUser teacher = SessionUser(
    uid: 'u1',
    email: 'teacher@demo.edu',
    role: UserRole.teacher,
    displayName: 'ATUL',
    schoolId: 'demo-school',
  );

  Widget wrapProfile() {
    return ProviderScope(
      overrides: [
        currentSessionProvider.overrideWithValue(teacher),
        schoolConfigProvider.overrideWith(
          (Ref ref) => Stream<SchoolConfig>.value(
            const SchoolConfig(id: 'demo-school', name: 'DEMO PUBLIC SCHOOL'),
          ),
        ),
        unreadNotificationCountProvider.overrideWithValue(4),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ProfileScreen()),
    );
  }

  group('Profile - the account actions vanished', () {
    testWidgets('all four are on screen and can be tapped', (
      WidgetTester tester,
    ) async {
      // A phone, not the test default of 800x600. The bug only appears in a
      // vertical scroll view, which is what a real screen gives it.
      tester.view.physicalSize = const Size(540, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapProfile());
      await tester.pumpAndSettle();

      // Log out is the one that matters most: without it a teacher is stuck
      // in the account they signed into.
      for (final String label in <String>[
        'Notifications',
        'Sync status',
        'Change password',
        'Log out',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsOneWidget, reason: label);

        final Size size = tester.getSize(find.text(label));
        expect(
          size.height,
          greaterThan(0),
          reason: '$label is in the tree but collapsed to nothing',
        );
      }
    });
  });

  group('Filter chips looked disabled', () {
    test('the theme states a label colour and a visible outline', () {
      final ChipThemeData chip = AppTheme.light().chipTheme;

      // The defect: labelStyle was handed to Chip with no colour at all, so
      // Material resolved it to a faded default and a row of filter chips
      // read as disabled rather than tappable.
      expect(
        chip.labelStyle?.color,
        isNotNull,
        reason: 'a label with no colour falls back to a washed-out default',
      );
      expect(chip.labelStyle!.color, AppColors.inkBody);

      // The outline was a translucent white, invisible on a pale gradient.
      final BorderSide? side = chip.side;
      expect(side, isNotNull);
      expect(
        side!.color.a,
        greaterThan(0.1),
        reason: 'a near-transparent outline leaves the chip with no edge',
      );
    });
  });

  group('Chat - the composer hides behind the keyboard', () {
    Widget wrapChat() {
      return ProviderScope(
        overrides: [
          currentSessionProvider.overrideWithValue(teacher),
          myChatsProvider.overrideWith(
            (Ref ref) => Stream<List<Chat>>.value(<Chat>[
              const Chat(
                id: 'c1',
                title: 'DEMO PUBLIC SCHOOL',
                members: <String>['u1', 'admin'],
                schoolId: 'demo-school',
              ),
            ]),
          ),
          messagesProvider('c1').overrideWith(
            (Ref ref) => Stream<List<ChatMessage>>.value(<ChatMessage>[
              ChatMessage(
                id: 'm1',
                chatId: 'c1',
                senderId: 'admin',
                senderName: 'Admin',
                sentAt: DateTime(2026, 9, 29, 22, 23),
                body: 'Document testing successfully done',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChatScreen(chatId: 'c1'),
        ),
      );
    }

    testWidgets('stays above a raised keyboard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(540, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapChat());
      await tester.pumpAndSettle();

      final Finder field = find.widgetWithText(TextField, 'Type a message');
      expect(field, findsOneWidget, reason: 'composer should exist at rest');
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(1200));

      // Now raise a 600px keyboard, the way a real one arrives.
      const double keyboard = 600;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(540, 1200),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: wrapChat(),
        ),
      );
      await tester.pumpAndSettle();

      final Rect rect = tester.getRect(
        find.widgetWithText(TextField, 'Type a message'),
      );

      // A Scaffold's bottomNavigationBar is NOT lifted by the keyboard - it
      // is pinned to the bottom of the scaffold and the keyboard covers it.
      // That is why the composer cannot live there.
      expect(
        rect.bottom,
        lessThanOrEqualTo(1200 - keyboard),
        reason:
            'the composer is underneath the keyboard, so you cannot see '
            'what you are typing',
      );
    });
  });
}
