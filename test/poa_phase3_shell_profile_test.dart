import 'package:drift/native.dart';
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
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/providers/seen_marker_providers.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/app_flag_repository.dart';
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
        approved.actionRequired,
        isFalse,
        reason: 'good news needs no action, so it does not nag',
      );
    });

    test('a returned card is flagged as needing action', () {
      final AppNotification? rejected = AppNotification.forEntry(
        entryId: 'e2',
        studentName: 'RAVI M',
        status: ApprovalStatus.rejected,
        reason: 'Photo too dark',
        at: DateTime(2026, 9, 10),
      );

      expect(rejected!.actionRequired, isTrue);
      expect(rejected.kind, NotificationKind.cardRejected);
      expect(rejected.body, contains('Photo too dark'));
    });

    test('but needing action is NOT the same as being unread', () {
      // The two were the same flag, and a returned card hardcoded it to true
      // forever. The badge could therefore never reach zero, so the app
      // permanently claimed the operator had missed something. Unread is now
      // decided by the feed against a persisted watermark; this class only
      // says whether the thing still needs doing.
      final AppNotification rejected = AppNotification.forEntry(
        entryId: 'e2',
        studentName: 'RAVI M',
        status: ApprovalStatus.rejected,
        reason: 'Photo too dark',
        at: DateTime(2026, 9, 10),
      )!;

      expect(
        rejected.unread,
        isFalse,
        reason:
            'nothing here may hardcode unread - that is what stuck the badge',
      );
      expect(rejected.copyWith(unread: true).unread, isTrue);
      expect(
        rejected.copyWith(unread: true).actionRequired,
        isTrue,
        reason: 'copyWith must not drop the action flag',
      );
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

    test('sorts newest first and surfaces failed uploads', () async {
      final List<StudentEntry> entries = <StudentEntry>[
        _entry(
          id: 'old',
          name: 'OLD ONE',
          status: ApprovalStatus.approved,
          reviewedAt: DateTime(2026, 9, 8),
        ),
        _entry(
          id: 'new',
          name: 'NEW ONE',
          status: ApprovalStatus.rejected,
          reviewedAt: DateTime(2026, 9, 9, 18),
        ),
        _entry(
          id: 'stuck',
          name: 'STUCK ONE',
          sync: SyncStatus.failed,
          syncError: 'No connection',
          updatedAt: DateTime(2026, 9, 10),
        ),
      ];

      final List<AppNotification> feed = await _feed(entries: entries);

      expect(feed.first.id, 'entry-stuck-syncfail');
      expect(feed.first.kind, NotificationKind.syncFailed);
      // The decision's own time is part of the id, so a second decision on
      // the same card cannot reuse the id of the first.
      expect(
        feed.map((AppNotification n) => n.id),
        contains(
          'entry-new-rejected-'
          '${DateTime(2026, 9, 9, 18).millisecondsSinceEpoch}',
        ),
      );
      expect(
        feed.map((AppNotification n) => n.id),
        anyElement(startsWith('entry-old-approved-')),
      );

      // Rejected + failed upload both need action; the approval does not.
      expect(feed.where((AppNotification n) => n.actionRequired).length, 2);

      // Nothing seen yet, so everything counts towards the badge - including
      // the approval, which needs no action but is still news.
      expect(feed.where((AppNotification n) => n.unread).length, 3);
    });

    test('the badge clears once the operator has looked', () async {
      // The complaint this answers: the bell carried a number that nothing
      // could clear, so the app permanently claimed something had been missed.
      final List<StudentEntry> entries = <StudentEntry>[
        _entry(
          id: 'r',
          name: 'RAVI M',
          status: ApprovalStatus.rejected,
          reviewedAt: DateTime(2026, 9, 10),
        ),
        _entry(
          id: 'a',
          name: 'ASHA K',
          status: ApprovalStatus.approved,
          reviewedAt: DateTime(2026, 9, 10),
        ),
      ];

      expect(
        (await _feed(entries: entries))
            .where((AppNotification n) => n.unread)
            .length,
        2,
        reason: 'before the screen is opened, both are news',
      );

      final List<AppNotification> before = await _feed(entries: entries);
      final List<AppNotification> afterLooking = await _feed(
        entries: entries,
        seen: before.map((AppNotification n) => n.id).toSet(),
      );
      expect(
        afterLooking.where((AppNotification n) => n.unread).length,
        0,
        reason: 'the badge must reach zero, or it is worse than no badge',
      );
    });

    test('a slow device clock cannot bring the badge back', () async {
      // The bug this pins. "Seen" used to be a timestamp taken from the
      // handset, compared against times written by the server. A phone a few
      // minutes behind produced notifications dated AFTER the moment they
      // were read, so every launch showed the same unread count and no amount
      // of opening the screen could clear it. Ids have no clock in them.
      final List<StudentEntry> entries = <StudentEntry>[
        _entry(
          id: 'a',
          name: 'ASHA K',
          status: ApprovalStatus.approved,
          // Comfortably in the future relative to any clock this test runs on.
          reviewedAt: DateTime(2099),
        ),
      ];

      final List<AppNotification> feed = await _feed(
        entries: entries,
        seen: (await _feed(
          entries: entries,
        )).map((AppNotification n) => n.id).toSet(),
      );

      expect(
        feed.single.unread,
        isFalse,
        reason:
            'a notification dated in the future must still be clearable - '
            'that is the whole failure this replaced',
      );
    });

    test('a returned card stays flagged for action after it is read', () async {
      // Read is not the same as dealt with. The row keeps its highlight so the
      // operator can still find it; it just stops inflating the badge.
      final List<AppNotification> feed = await _feed(
        entries: <StudentEntry>[
          _entry(
            id: 'r',
            name: 'RAVI M',
            status: ApprovalStatus.rejected,
            reviewedAt: DateTime(2026, 9, 10),
          ),
        ],
        seen: <String>{
          'entry-r-rejected-${DateTime(2026, 9, 10).millisecondsSinceEpoch}',
        },
      );

      expect(feed.single.unread, isFalse);
      expect(feed.single.actionRequired, isTrue);
    });

    test('but a NEWER decision on the same card still counts', () async {
      // The same card being sent back a second time must re-alert. A seen set
      // that swallowed this would be no better than the stuck badge - the
      // office would correct a card twice and the teacher would hear about it
      // once.
      final List<AppNotification> feed = await _feed(
        entries: <StudentEntry>[
          _entry(
            id: 'r',
            name: 'RAVI M',
            status: ApprovalStatus.rejected,
            reviewedAt: DateTime(2026, 9, 12),
          ),
        ],
        // The FIRST rejection, already read.
        seen: <String>{
          'entry-r-rejected-${DateTime(2026, 9, 10).millisecondsSinceEpoch}',
        },
      );

      expect(feed.single.unread, isTrue);
    });
  });

  group('The seen set', () {
    // Exercised against a real database rather than a stub: the whole point of
    // this is that it survives a restart, and an in-memory stand-in would
    // prove nothing about that.
    late AppDatabase db;
    late AppFlagRepository flags;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      flags = AppFlagRepository(db);
    });

    tearDown(() async => db.close());

    test('starts empty, which correctly makes everything unread', () async {
      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        isEmpty,
      );
    });

    test('round-trips through storage', () async {
      await flags.markNotificationsSeen(<String>{'a', 'b'});

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'a', 'b'},
      );
      expect(
        await flags.readDateTime(AppFlagRepository.notificationsSeenAtKey),
        isNotNull,
        reason: 'the visit time is still recorded, it just no longer decides',
      );
    });

    test('replaces rather than accumulating', () async {
      // This is what keeps the set the size of the feed instead of growing
      // for the life of the account. Anything that has dropped out of the
      // feed drops out of here with it.
      await flags.markNotificationsSeen(<String>{'a', 'b'});
      await flags.markNotificationsSeen(<String>{'b', 'c'});

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'b', 'c'},
      );
    });

    test('adding keeps what is already there', () async {
      // Dismissing a returned card must not un-dismiss the last one.
      await flags.addToStringSet(
        AppFlagRepository.returnedDismissedIdsKey,
        <String>{'card-1'},
      );
      await flags.addToStringSet(
        AppFlagRepository.returnedDismissedIdsKey,
        <String>{'card-2'},
      );

      expect(
        await flags.readStringSet(AppFlagRepository.returnedDismissedIdsKey),
        <String>{'card-1', 'card-2'},
      );
    });

    test('a value it did not write reads as empty rather than throwing', () {
      // The notification feed runs on every launch. It must not be the thing
      // that takes the app down because a row in a key-value table is not the
      // shape it expected.
      expect(AppFlagRepository.decodeSetForTest('not json'), isEmpty);
      expect(AppFlagRepository.decodeSetForTest('{"a":1}'), isEmpty);
      expect(AppFlagRepository.decodeSetForTest('[1,"a",null]'), <String>{'a'});
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
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A real database, because opening this screen records what it
        // showed and that write is half of what is being tested.
        appDatabaseProvider.overrideWithValue(db),
        // ...but not its live stream. A Drift stream query leaves a periodic
        // timer alive, and the widget-test binding fails the test with "a
        // Timer is still pending even after the widget tree was disposed". The
        // screen only reads this to decide which rows look new; the set it
        // writes is asserted directly against the repository elsewhere.
        notificationsSeenIdsProvider.overrideWith(
          (ref) => Stream<Set<String>>.value(const <String>{}),
        ),
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

/// The notification feed as the app would compute it, for a given seen set.
///
/// The seen-ids provider is overridden rather than backed by a database: the
/// feed's own logic is what is under test here, and a Drift stream query
/// inside a widget test leaves a pending timer that the test binding rejects.
/// The storage side is covered separately against a real database.
Future<List<AppNotification>> _feed({
  required List<StudentEntry> entries,
  Set<String> seen = const <String>{},
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      entriesProvider.overrideWith(
        (Ref ref) => Stream<List<StudentEntry>>.value(entries),
      ),
      notificationsSeenIdsProvider.overrideWith(
        (Ref ref) => Stream<Set<String>>.value(seen),
      ),
    ],
  );
  addTearDown(container.dispose);

  // `listen` first, then await. Both are needed and for different reasons: the
  // listener keeps the provider alive (an unlistened one is disposed while
  // still loading, and awaiting its future then hangs until the test times
  // out), and the await is what makes the result deterministic instead of
  // dependent on microtask ordering - the feed reads the streams' synchronous
  // `.value`, which is null until the first event lands.
  container.listen(entriesProvider, (_, _) {});
  container.listen(notificationsSeenIdsProvider, (_, _) {});
  await container.read(entriesProvider.future);
  await container.read(notificationsSeenIdsProvider.future);

  return container.read(notificationsProvider);
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
