import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/notifications/application/notification_providers.dart';
import 'package:flutter_id_card/features/notifications/domain/app_notification.dart';
import 'package:flutter_id_card/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_id_card/features/photo_capture/domain/photo_adjustments.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan-of-Action Phase 3: the app shell, Profile, Notifications, photo zoom.
void main() {
  group('Notification feed', () {
    test('is derived from entry state, so it cannot go stale', () {
      final DateTime now = DateTime(2026, 9, 10, 9);

      final AppNotification? approved = AppNotification.forEntry(
        entryId: 'e1',
        studentName: 'ASHA K',
        status: ApprovalStatus.approved,
        reason: null,
        at: now,
      );
      expect(approved, isNotNull);
      expect(approved!.kind, NotificationKind.cardApproved);
      expect(approved.route, '/submissions/e1');
      expect(
        approved.unread,
        isFalse,
        reason: 'good news needs no action, so it does not nag',
      );
    });

    test('a returned card stays unread because it needs the operator', () {
      final AppNotification? rejected = AppNotification.forEntry(
        entryId: 'e2',
        studentName: 'RAVI M',
        status: ApprovalStatus.rejected,
        reason: 'Photo too dark',
        at: DateTime(2026, 9, 10),
      );

      expect(rejected!.unread, isTrue);
      expect(rejected.kind, NotificationKind.cardRejected);
      expect(rejected.body, contains('Photo too dark'));
    });

    test('pending produces nothing - no news is not news', () {
      expect(
        AppNotification.forEntry(
          entryId: 'e3',
          studentName: 'X',
          status: ApprovalStatus.pending,
          reason: null,
          at: DateTime(2026, 9, 10),
        ),
        isNull,
      );
    });

    test('falls back to a name when the student has none', () {
      final AppNotification? n = AppNotification.forEntry(
        entryId: 'e4',
        studentName: '   ',
        status: ApprovalStatus.printed,
        reason: null,
        at: DateTime(2026, 9, 10),
      );
      expect(n!.body, startsWith('A card'));
    });

    testWidgets('sorts newest first and surfaces failed uploads', (
      WidgetTester tester,
    ) async {
      final List<StudentEntry> entries = <StudentEntry>[
        _entry(
          id: 'old',
          name: 'OLD ONE',
          status: ApprovalStatus.approved,
          reviewedAt: DateTime(2026, 9, 1),
        ),
        _entry(
          id: 'new',
          name: 'NEW ONE',
          status: ApprovalStatus.rejected,
          reviewedAt: DateTime(2026, 9, 9),
        ),
        _entry(
          id: 'stuck',
          name: 'STUCK ONE',
          sync: SyncStatus.failed,
          syncError: 'No connection',
          updatedAt: DateTime(2026, 9, 10),
        ),
      ];

      late List<AppNotification> feed;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entriesProvider.overrideWith(
              (ref) => Stream<List<StudentEntry>>.value(entries),
            ),
          ],
          child: Consumer(
            builder: (BuildContext c, WidgetRef ref, _) {
              feed = ref.watch(notificationsProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(feed.first.id, 'entry-stuck-syncfail');
      expect(feed.first.kind, NotificationKind.syncFailed);
      expect(feed.map((AppNotification n) => n.id), contains('entry-new-rejected'));
      expect(feed.map((AppNotification n) => n.id), contains('entry-old-approved'));

      // Rejected + failed upload both need action; the approval does not.
      expect(feed.where((AppNotification n) => n.unread).length, 2);
    });
  });

  group('Notifications screen', () {
    testWidgets('lists items newest first', (WidgetTester tester) async {
      await _pumpNotifications(tester, <StudentEntry>[
        _entry(
          id: 'a',
          name: 'ASHA K',
          status: ApprovalStatus.approved,
          reviewedAt: DateTime(2026, 9, 9),
        ),
      ]);

      expect(find.text('Card approved'), findsOneWidget);
      expect(find.textContaining('ASHA K'), findsOneWidget);
    });

    testWidgets('has a useful empty state', (WidgetTester tester) async {
      await _pumpNotifications(tester, const <StudentEntry>[]);
      expect(find.text('Nothing new'), findsOneWidget);
    });
  });

  group('Photo zoom', () {
    test('is neutral by default and never widens past the detected frame', () {
      const PhotoAdjustments neutral = PhotoAdjustments.neutral;
      expect(neutral.zoom, 0);
      expect(neutral.cropScale, 1.0);
      expect(neutral.isNeutral, isTrue);
    });

    test('tightens the crop window as zoom rises', () {
      const PhotoAdjustments half = PhotoAdjustments(zoom: 0.5);
      const PhotoAdjustments full = PhotoAdjustments(zoom: 1);

      expect(half.cropScale, lessThan(1.0));
      expect(full.cropScale, lessThan(half.cropScale));
      expect(
        full.cropScale,
        closeTo(1 - PhotoAdjustments.maxZoomShrink, 1e-9),
        reason: 'a full zoom must stop at the documented shrink limit, not 0',
      );
    });

    test('clamps out-of-range values rather than inverting the crop', () {
      expect(const PhotoAdjustments(zoom: 5).cropScale, greaterThan(0));
      expect(const PhotoAdjustments(zoom: -5).cropScale, 1.0);
    });

    test('counts as a non-neutral adjustment so Reset offers itself', () {
      expect(const PhotoAdjustments(zoom: 0.4).isNeutral, isFalse);
    });

    test('reset clears zoom but keeps the pipeline toggles', () {
      const PhotoAdjustments dirty = PhotoAdjustments(
        zoom: 0.8,
        brightness: 0.5,
        removeBackground: false,
        autoFrame: false,
      );
      final PhotoAdjustments clean = dirty.reset();

      expect(clean.zoom, 0);
      expect(clean.brightness, 0);
      expect(clean.removeBackground, isFalse);
      expect(clean.autoFrame, isFalse);
    });
  });

  group('Role gating', () {
    test('teacher and school are both operators, admin is not', () {
      expect(UserRole.teacher.isOperator, isTrue);
      expect(UserRole.school.isOperator, isTrue);
      expect(UserRole.admin.isOperator, isFalse);
    });

    test('a teacher session is not admin', () {
      const SessionUser teacher = SessionUser(
        uid: 'u1',
        email: 't@example.com',
        role: UserRole.teacher,
        schoolId: 'school-1',
      );
      expect(teacher.isAdmin, isFalse);
      expect(
        teacher.canEnterData,
        isTrue,
        reason: 'a teacher is tied to a school and submits cards for it',
      );
    });
  });
}

Future<void> _pumpNotifications(
  WidgetTester tester,
  List<StudentEntry> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entriesProvider.overrideWith(
          (ref) => Stream<List<StudentEntry>>.value(entries),
        ),
        currentSessionProvider.overrideWithValue(
          const SessionUser(
            uid: 'u1',
            email: 'teacher@example.com',
            role: UserRole.teacher,
            schoolId: 'school-1',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const NotificationsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StudentEntry _entry({
  required String id,
  required String name,
  ApprovalStatus status = ApprovalStatus.pending,
  SyncStatus sync = SyncStatus.synced,
  String? syncError,
  DateTime? reviewedAt,
  DateTime? updatedAt,
}) {
  final DateTime base = DateTime(2026, 9, 9);
  return StudentEntry(
    id: id,
    schoolId: 'school-1',
    name: name,
    studentClass: '5',
    approvalStatus: status,
    reviewedAt: reviewedAt,
    syncStatus: sync,
    syncError: syncError,
    createdAt: base,
    updatedAt: updatedAt ?? base,
  );
}
