import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/presentation/requests_queue_screen.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/managed_user.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/messaging/presentation/broadcast_screen.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan-of-Action Phase 4: the cross-school request queue and bulk messaging.
void main() {
  group('Requests queue', () {
    testWidgets('opens on the pending backlog, not on everything', (
      WidgetTester tester,
    ) async {
      await _pumpQueue(tester, <StudentEntry>[
        _entry(id: 'p', name: 'WAITING KID', school: 's1'),
        _entry(
          id: 'a',
          name: 'DONE KID',
          school: 's1',
          status: ApprovalStatus.approved,
        ),
      ]);

      expect(
        find.text('WAITING KID'),
        findsOneWidget,
        reason: 'the queue exists to clear a backlog, so it opens on it',
      );
      expect(find.text('DONE KID'), findsNothing);
    });

    testWidgets('shows requests from every school at once', (
      WidgetTester tester,
    ) async {
      await _pumpQueue(
        tester,
        <StudentEntry>[
          _entry(id: '1', name: 'ALPHA KID', school: 's1'),
          _entry(id: '2', name: 'BETA KID', school: 's2'),
        ],
        schools: <SchoolConfig>[
          SchoolConfig.fallback('s1').copyWith(name: 'ALPHA SCHOOL'),
          SchoolConfig.fallback('s2').copyWith(name: 'BETA SCHOOL'),
        ],
      );

      expect(find.text('ALPHA KID'), findsOneWidget);
      expect(find.text('BETA KID'), findsOneWidget);
      expect(find.text('ALPHA SCHOOL'), findsOneWidget);
      expect(find.text('BETA SCHOOL'), findsOneWidget);
    });

    testWidgets('offers approve and send-back on a pending row only', (
      WidgetTester tester,
    ) async {
      await _pumpQueue(tester, <StudentEntry>[
        _entry(id: 'p', name: 'WAITING KID', school: 's1'),
      ]);

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Send back'), findsOneWidget);
    });

    testWidgets('an approved row carries no review buttons', (
      WidgetTester tester,
    ) async {
      await _pumpQueue(
        tester,
        <StudentEntry>[
          _entry(
            id: 'a',
            name: 'DONE KID',
            school: 's1',
            status: ApprovalStatus.approved,
          ),
        ],
        // Switch off the default pending filter so the approved row shows.
        tapStatus: 'Approved (1)',
      );

      expect(find.text('DONE KID'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Send back'), findsNothing);
    });

    testWidgets('celebrates an empty backlog rather than showing a blank', (
      WidgetTester tester,
    ) async {
      await _pumpQueue(tester, <StudentEntry>[
        _entry(
          id: 'a',
          name: 'DONE KID',
          school: 's1',
          status: ApprovalStatus.approved,
        ),
      ]);

      expect(find.text('Queue is clear'), findsOneWidget);
    });

    testWidgets('flags a request with no photo', (WidgetTester tester) async {
      await _pumpQueue(tester, <StudentEntry>[
        _entry(id: 'p', name: 'NO PHOTO KID', school: 's1'),
      ]);

      expect(
        find.text('No photo'),
        findsOneWidget,
        reason: 'approving a photoless card would waste a slot on the sheet',
      );
    });
  });

  group('Broadcast recipients', () {
    testWidgets('defaults to everyone and counts them', (
      WidgetTester tester,
    ) async {
      await _pumpBroadcast(tester, _users());

      expect(find.text('Bulk Message'), findsOneWidget);
      // Two active operators; the admin and the disabled account are excluded.
      expect(find.text('Send to 2 recipient(s)'), findsOneWidget);
    });

    testWidgets('excludes admins and deactivated accounts', (
      WidgetTester tester,
    ) async {
      await _pumpBroadcast(tester, <ManagedUser>[
        _user('admin', role: UserRole.admin),
        _user('off', active: false),
      ]);

      expect(
        find.text('Choose at least one recipient'),
        findsOneWidget,
        reason: 'an admin should not receive their own announcement, and a '
            'disabled account cannot sign in to read one',
      );
    });

    testWidgets('switching to By school narrows the picker', (
      WidgetTester tester,
    ) async {
      await _pumpBroadcast(tester, _users());

      await tester.tap(find.text('By school'));
      await tester.pumpAndSettle();

      expect(find.text('ALPHA SCHOOL'), findsOneWidget);
      // Nothing ticked yet, so nobody is selected.
      expect(find.text('Choose at least one recipient'), findsOneWidget);
    });
  });

  group('BroadcastResult', () {
    test('a clean send reports every recipient delivered', () {
      final BroadcastResult r = BroadcastResult(
        recipients: 12,
        schools: 3,
        failures: const <String>[],
        sentAt: DateTime(2026, 9, 10),
      );

      expect(r.isComplete, isTrue);
      expect(r.delivered, 12);
    });

    test('a partial send is not rounded up to success', () {
      final BroadcastResult r = BroadcastResult(
        recipients: 10,
        schools: 2,
        failures: const <String>['RAVI M', 'ASHA K'],
        sentAt: DateTime(2026, 9, 10),
      );

      expect(r.isComplete, isFalse);
      expect(r.delivered, 8);
    });
  });

  group('Admin stats', () {
    test('counts printed separately but keeps it printable for reprints', () {
      // A printed card still counts toward "ready to print" because reprints
      // are routine - see ApprovalStatus.isPrintable.
      expect(ApprovalStatus.printed.isPrintable, isTrue);
      expect(const AdminStats().printed, 0);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<void> _pumpQueue(
  WidgetTester tester,
  List<StudentEntry> entries, {
  List<SchoolConfig>? schools,
  String? tapStatus,
}) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allEntriesProvider.overrideWith(
          (ref) => Stream<List<StudentEntry>>.value(entries),
        ),
        allSchoolsProvider.overrideWith(
          (ref) => Stream<List<SchoolConfig>>.value(
            schools ??
                <SchoolConfig>[
                  SchoolConfig.fallback('s1').copyWith(name: 'ALPHA SCHOOL'),
                ],
          ),
        ),
        currentSessionProvider.overrideWithValue(
          const SessionUser(
            uid: 'admin-1',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const RequestsQueueScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (tapStatus != null) {
    await tester.tap(find.text(tapStatus));
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpBroadcast(
  WidgetTester tester,
  List<ManagedUser> users,
) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allUsersProvider.overrideWith(
          (ref) => Stream<List<ManagedUser>>.value(users),
        ),
        allSchoolsProvider.overrideWith(
          (ref) => Stream<List<SchoolConfig>>.value(<SchoolConfig>[
            SchoolConfig.fallback('s1').copyWith(name: 'ALPHA SCHOOL'),
          ]),
        ),
        currentSessionProvider.overrideWithValue(
          const SessionUser(
            uid: 'admin-1',
            email: 'admin@test.com',
            role: UserRole.admin,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const BroadcastScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<ManagedUser> _users() => <ManagedUser>[
      _user('a'),
      _user('b'),
      _user('admin', role: UserRole.admin),
      _user('off', active: false),
    ];

ManagedUser _user(
  String id, {
  UserRole role = UserRole.school,
  bool active = true,
}) =>
    ManagedUser(
      uid: id,
      email: '$id@test.com',
      displayName: id.toUpperCase(),
      role: role,
      schoolId: role == UserRole.admin ? null : 's1',
      active: active,
    );

StudentEntry _entry({
  required String id,
  required String name,
  required String school,
  ApprovalStatus status = ApprovalStatus.pending,
}) {
  final DateTime now = DateTime(2026, 9, 10);
  return StudentEntry(
    id: id,
    schoolId: school,
    name: name,
    studentClass: '5',
    division: 'A',
    approvalStatus: status,
    createdAt: now,
    updatedAt: now,
  );
}
