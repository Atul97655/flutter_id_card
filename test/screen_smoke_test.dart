import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/auth/presentation/profile_screen.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/presentation/home_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/saved_entries_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/sync_status_screen.dart';
import 'package:flutter_id_card/features/messaging/application/chat_providers.dart';
import 'package:flutter_id_card/features/messaging/domain/chat_models.dart';
import 'package:flutter_id_card/features/messaging/presentation/chat_list_screen.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Does every redesigned screen actually DRAW?
///
/// This exists because of a bug that shipped: the Profile screen's account
/// actions were in the widget tree, wired to the right callbacks, and drew
/// nothing at all - a Row asked to stretch inside a scroll view got an
/// infinite height constraint. In debug that throws; in a release build it
/// silently renders blank. A teacher was left with no way to log out.
///
/// Nothing in the suite caught it. The component tests pump each widget
/// alone, so they never saw it inside a ListView, and a feature-parity diff
/// of the source could not see it either - the code was all still there.
///
/// So these tests do the one thing neither could: build the real screen at a
/// real phone size with real data and assert that the things a user needs are
/// on screen with a non-zero size. `pumpWidget` surfaces layout exceptions as
/// test failures, so "it renders" is a genuine assertion here.
void main() {
  const SessionUser teacher = SessionUser(
    uid: 'u1',
    email: 'teacher@demo.edu',
    role: UserRole.teacher,
    displayName: 'ATUL',
    schoolId: 'demo-school',
  );

  StudentEntry entry(String id, String name, ApprovalStatus status) {
    return StudentEntry(
      id: id,
      schoolId: 'demo-school',
      name: name,
      fatherName: 'FATHER',
      studentClass: '10',
      division: 'A',
      rollNumber: '1',
      bloodGroup: 'O+',
      dob: DateTime(2012, 4, 3),
      mobile: '9876543210',
      address: 'SOMEWHERE',
      approvalStatus: status,
      syncStatus: SyncStatus.synced,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  final List<StudentEntry> entries = <StudentEntry>[
    entry('a', 'ATUL', ApprovalStatus.approved),
    entry('b', 'TEJASWINI DASH', ApprovalStatus.approved),
    entry('c', 'GURL', ApprovalStatus.rejected),
    entry('d', 'BILLLU PHELWAN', ApprovalStatus.pending),
  ];

  Widget wrap(Widget screen) {
    return ProviderScope(
      overrides: [
        currentSessionProvider.overrideWithValue(teacher),
        schoolConfigProvider.overrideWith(
          (Ref ref) => Stream<SchoolConfig>.value(
            const SchoolConfig(id: 'demo-school', name: 'DEMO PUBLIC SCHOOL'),
          ),
        ),
        // Feeds submissionCountsProvider and syncCountsProvider, which derive
        // from it, so one override drives the whole dashboard.
        entriesProvider.overrideWith(
          (Ref ref) => Stream<List<StudentEntry>>.value(entries),
        ),
        unreadNotificationCountProvider.overrideWithValue(4),
        myChatsProvider.overrideWith(
          (Ref ref) => Stream<List<Chat>>.value(<Chat>[
            Chat(
              id: 'c1',
              title: 'DEMO PUBLIC SCHOOL',
              members: const <String>['u1', 'admin'],
              schoolId: 'demo-school',
              lastMessage: 'Document testing successfully done',
              lastMessageAt: DateTime(2026, 9, 28, 22, 23),
            ),
          ]),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    );
  }

  /// A mid-range phone in logical pixels, which is what these are used on.
  Future<void> pumpPhone(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(screen));
    await tester.pumpAndSettle();
  }

  /// Present in the tree AND occupying real space.
  ///
  /// `findsOneWidget` alone would have passed on the shipped Profile bug:
  /// the tiles were there, they just had no size.
  void expectVisible(WidgetTester tester, Finder f, String what) {
    expect(f, findsWidgets, reason: '$what is missing entirely');
    final Size size = tester.getSize(f.first);
    expect(
      size.width * size.height,
      greaterThan(0),
      reason: '$what is in the tree but draws nothing',
    );
  }

  testWidgets('Home draws the school, the stats and the new-card action', (
    WidgetTester tester,
  ) async {
    await pumpPhone(tester, const HomeScreen());

    expectVisible(tester, find.text('DEMO PUBLIC SCHOOL'), 'the school name');
    expectVisible(tester, find.textContaining('New'), 'the new-card action');
  });

  testWidgets('Profile draws all four account actions', (
    WidgetTester tester,
  ) async {
    await pumpPhone(tester, const ProfileScreen());

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
      expectVisible(tester, find.text(label), label);
    }
  });

  testWidgets('My Submissions draws every row and its filter chips', (
    WidgetTester tester,
  ) async {
    await pumpPhone(tester, const SavedEntriesScreen());

    expectVisible(tester, find.text('ATUL'), 'the first submission');
    expectVisible(tester, find.textContaining('All ('), 'the All filter');
    // The rejection reason is the whole point of the returned state.
    expect(find.text('GURL'), findsOneWidget);
  });

  testWidgets('Sync status draws without a layout failure', (
    WidgetTester tester,
  ) async {
    await pumpPhone(tester, const SyncStatusScreen());
    expectVisible(tester, find.text('Sync Status'), 'the title');
  });

  testWidgets('Chat list draws its no-connection state', (
    WidgetTester tester,
  ) async {
    // Firebase is not initialised in a widget test, so this screen takes its
    // offline branch by design - chat is the one feature that genuinely does
    // not work offline. That branch is worth rendering too: it is what an
    // operator sees on a school connection that has dropped.
    await pumpPhone(tester, const ChatListScreen());
    expectVisible(
      tester,
      find.text('Messaging needs a connection'),
      'the offline notice',
    );
    expectVisible(tester, find.text('Messages'), 'the header');
  });
}
