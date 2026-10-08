import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/auth/presentation/profile_screen.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/presentation/data_entry_screen.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_screen.dart';
import 'package:flutter_id_card/features/messaging/presentation/send_id_card_screen.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/seen_marker_providers.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sending an ID card from a conversation, and making one from there.
///
/// Two complaints drive this file. The picker was a dead end for the one
/// person most likely to open it - a teacher whose student has no card yet
/// was told "No approved cards yet" and had to leave the conversation to do
/// anything about it. And the ID card itself, the single thing this app
/// exists to move, was buried six rows down a sheet behind the paperclip,
/// under Document, Photos, and two rows that are greyed out.
void main() {
  const SessionUser teacher = SessionUser(
    uid: 'u1',
    email: 'teacher@demo.edu',
    role: UserRole.teacher,
    displayName: 'ATUL',
    schoolId: 'demo-school',
  );

  StudentEntry entry(
    String id,
    String name,
    ApprovalStatus status, {
    DateTime? createdAt,
  }) {
    return StudentEntry(
      id: id,
      schoolId: 'demo-school',
      name: name,
      studentClass: '10',
      division: 'A',
      rollNumber: '1',
      approvalStatus: status,
      syncStatus: SyncStatus.synced,
      createdAt: createdAt ?? DateTime(2026, 9, 1),
      updatedAt: createdAt ?? DateTime(2026, 9, 1),
    );
  }

  Widget wrap(Widget screen, List<StudentEntry> entries) {
    return ProviderScope(
      overrides: [
        currentSessionProvider.overrideWithValue(teacher),
        entriesProvider.overrideWith(
          (Ref ref) => Stream<List<StudentEntry>>.value(entries),
        ),
        schoolConfigProvider.overrideWith(
          (Ref ref) => Stream<SchoolConfig>.value(
            const SchoolConfig(id: 'demo-school', name: 'DEMO PUBLIC SCHOOL'),
          ),
        ),
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
              body: 'Hello',
            ),
          ]),
        ),
        notificationsSeenIdsProvider.overrideWith(
          (Ref ref) => Stream<Set<String>>.value(const <String>{}),
        ),
        returnedDismissedIdsProvider.overrideWith(
          (Ref ref) => Stream<Set<String>>.value(const <String>{}),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    );
  }

  Future<void> pumpPhone(
    WidgetTester tester,
    Widget screen,
    List<StudentEntry> entries,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(screen, entries));
    await tester.pumpAndSettle();
  }

  group('The ID card picker', () {
    testWidgets('offers making a new card ABOVE the ones that exist', (
      WidgetTester tester,
    ) async {
      await pumpPhone(
        tester,
        const SendIdCardScreen(recipientLabel: 'DEMO PUBLIC SCHOOL'),
        <StudentEntry>[
          entry('a', 'ATUL', ApprovalStatus.approved),
          entry('b', 'TEJASWINI DASH', ApprovalStatus.approved),
        ],
      );

      final Finder create = find.text('Create a new ID card');
      expect(create, findsOneWidget);

      // Above, not merely present. Underneath a scrolling list of approved
      // cards it would be invisible to the person who needs it most.
      expect(
        tester.getRect(create).top,
        lessThan(tester.getRect(find.text('ATUL')).top),
        reason: 'the create action has to come before the existing cards',
      );
    });

    testWidgets('is not a dead end when nothing has been approved yet', (
      WidgetTester tester,
    ) async {
      // The shipped behaviour: an empty state, a back button, and no way
      // forward. The teacher had to abandon the conversation.
      await pumpPhone(
        tester,
        const SendIdCardScreen(recipientLabel: 'DEMO PUBLIC SCHOOL'),
        <StudentEntry>[],
      );

      expect(find.text('Create a new ID card'), findsOneWidget);
      expect(find.text('No approved cards yet'), findsOneWidget);
    });

    testWidgets('create opens the form in a mode that comes BACK here', (
      WidgetTester tester,
    ) async {
      // The trap this avoids: the router's own `/entry/new` ends at a receipt
      // screen reached with `go`, which replaces the navigation stack. Used
      // from a conversation that would close the conversation, and the
      // teacher would come back from the home screen to find the message they
      // were half-way through gone.
      await pumpPhone(
        tester,
        const SendIdCardScreen(recipientLabel: 'DEMO PUBLIC SCHOOL'),
        <StudentEntry>[],
      );

      await tester.tap(find.text('Create a new ID card'));
      await tester.pumpAndSettle();

      final DataEntryScreen form = tester.widget<DataEntryScreen>(
        find.byType(DataEntryScreen),
      );
      expect(form.returnsEntryId, isTrue);
      expect(form.entryId, isNull, reason: 'this is a new card, not an edit');

      // And the picker is still underneath, waiting.
      expect(find.byType(SendIdCardScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows a freshly submitted card as being with the office', (
      WidgetTester tester,
    ) async {
      // A card that vanished the moment it was submitted would read as work
      // that was lost, and the teacher would make it again.
      await pumpPhone(
        tester,
        const SendIdCardScreen(recipientLabel: 'DEMO PUBLIC SCHOOL'),
        <StudentEntry>[
          entry(
            'new',
            'BILLLU PHELWAN',
            ApprovalStatus.pending,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ],
      );

      expect(find.text('WITH THE OFFICE'), findsOneWidget);
      expect(find.text('BILLLU PHELWAN'), findsOneWidget);
    });

    testWidgets('an old pending card does not clutter the picker', (
      WidgetTester tester,
    ) async {
      // Everything the school has ever submitted and not had back would bury
      // the point. Only what this teacher just did belongs here.
      await pumpPhone(
        tester,
        const SendIdCardScreen(recipientLabel: 'DEMO PUBLIC SCHOOL'),
        <StudentEntry>[
          entry('old', 'SOMEONE ELSE', ApprovalStatus.pending),
        ],
      );

      expect(find.text('WITH THE OFFICE'), findsNothing);
      expect(find.text('SOMEONE ELSE'), findsNothing);
    });

    testWidgets('a pending card cannot be selected and sent', (
      WidgetTester tester,
    ) async {
      // The rule this screen exists to enforce. Sending an unapproved card
      // would ask the office to review it in a chat, where the decision has
      // nowhere to be recorded.
      await pumpPhone(
        tester,
        const SendIdCardScreen(recipientLabel: 'DEMO PUBLIC SCHOOL'),
        <StudentEntry>[
          entry(
            'new',
            'BILLLU PHELWAN',
            ApprovalStatus.pending,
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.tap(find.text('BILLLU PHELWAN'));
      await tester.pumpAndSettle();

      final FilledButton send = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send ID Card'),
      );
      expect(
        send.onPressed,
        isNull,
        reason: 'tapping a pending card must not arm the send button',
      );
    });
  });

  group('The composer', () {
    testWidgets('has an ID card button of its own, next to the paperclip', (
      WidgetTester tester,
    ) async {
      await pumpPhone(tester, const ChatScreen(chatId: 'c1'), <StudentEntry>[
        entry('a', 'ATUL', ApprovalStatus.approved),
      ]);

      expect(
        find.byTooltip('Send an ID card'),
        findsOneWidget,
        reason:
            'the one attachment this app is for was three taps and a read '
            'down a sheet',
      );
      expect(find.byTooltip('Attach'), findsOneWidget);
    });

    testWidgets('that button opens the picker directly', (
      WidgetTester tester,
    ) async {
      await pumpPhone(tester, const ChatScreen(chatId: 'c1'), <StudentEntry>[
        entry('a', 'ATUL', ApprovalStatus.approved),
      ]);

      await tester.tap(find.byTooltip('Send an ID card'));
      await tester.pumpAndSettle();

      expect(find.byType(SendIdCardScreen), findsOneWidget);
      // Straight there - no attachment tray in between.
      expect(find.text('Photos & videos'), findsNothing);
    });

    testWidgets('both buttons and the field fit a narrow phone', (
      WidgetTester tester,
    ) async {
      // Two round buttons, a field and a send button on a 320pt screen. A
      // composer that overflows is the kind of thing that only shows up on
      // somebody's actual handset.
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(const ChatScreen(chatId: 'c1'), <StudentEntry>[]),
      );
      await tester.pumpAndSettle();

      final Rect field = tester.getRect(
        find.widgetWithText(TextField, 'Type a message'),
      );
      expect(field.width, greaterThan(60), reason: 'the field was squeezed out');
      expect(field.right, lessThanOrEqualTo(320));
    });
  });

  group('The returned-cards banner', () {
    testWidgets('can be dismissed', (WidgetTester tester) async {
      // It used to be permanent: nothing could clear it, so it came back on
      // every launch and after every reinstall. An alert nobody can silence
      // is one people learn to look past.
      await pumpPhone(tester, const ProfileScreen(), <StudentEntry>[
        entry('c', 'GURL', ApprovalStatus.rejected),
      ]);

      expect(find.text('1 card came back'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Dismiss returned cards'),
        findsOneWidget,
        reason: 'a banner with no way out is the bug being fixed',
      );
    });

    testWidgets('stays gone for a card already dismissed', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWithValue(teacher),
            entriesProvider.overrideWith(
              (Ref ref) => Stream<List<StudentEntry>>.value(<StudentEntry>[
                entry('c', 'GURL', ApprovalStatus.rejected),
              ]),
            ),
            schoolConfigProvider.overrideWith(
              (Ref ref) => Stream<SchoolConfig>.value(
                const SchoolConfig(
                  id: 'demo-school',
                  name: 'DEMO PUBLIC SCHOOL',
                ),
              ),
            ),
            notificationsSeenIdsProvider.overrideWith(
              (Ref ref) => Stream<Set<String>>.value(const <String>{}),
            ),
            returnedDismissedIdsProvider.overrideWith(
              (Ref ref) => Stream<Set<String>>.value(const <String>{'c'}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 card came back'), findsNothing);
      expect(
        find.text('View all submissions'),
        findsOneWidget,
        reason: 'the panel still has to offer a way into the list',
      );
    });
  });
}
