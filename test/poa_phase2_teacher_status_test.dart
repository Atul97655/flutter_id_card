import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/features/data_entry/presentation/request_detail_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/saved_entries_screen.dart';
import 'package:flutter_id_card/features/data_entry/presentation/submission_success_screen.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/approval_status_chip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan-of-Action Phase 2: the teacher can finally see what the office decided.
///
/// Before this, `ApprovalStatus` and `rejectionReason` appeared nowhere on the
/// operator side - these tests exist mainly to stop that regressing.
void main() {
  group('My Submissions', () {
    testWidgets('filters on approval status, not sync status', (
      WidgetTester tester,
    ) async {
      await _pumpEntries(tester, <StudentEntry>[
        _entry(id: 'p', name: 'PENDING KID', status: ApprovalStatus.pending),
        _entry(id: 'a', name: 'APPROVED KID', status: ApprovalStatus.approved),
        _entry(id: 'r', name: 'PRINTED KID', status: ApprovalStatus.printed),
      ]);

      // All four approval tabs are offered, with counts.
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Pending review (1)'), findsOneWidget);
      expect(find.text('Approved (1)'), findsOneWidget);
      expect(find.text('Printed (1)'), findsOneWidget);
      expect(find.text('Rejected (0)'), findsOneWidget);

      // Everything is listed to begin with.
      expect(find.text('PENDING KID'), findsOneWidget);
      expect(find.text('APPROVED KID'), findsOneWidget);
      expect(find.text('PRINTED KID'), findsOneWidget);

      await tester.tap(find.text('Printed (1)'));
      await tester.pumpAndSettle();

      expect(find.text('PRINTED KID'), findsOneWidget);
      expect(find.text('PENDING KID'), findsNothing);
      expect(find.text('APPROVED KID'), findsNothing);
    });

    testWidgets('shows the rejection reason on the row', (
      WidgetTester tester,
    ) async {
      await _pumpEntries(tester, <StudentEntry>[
        _entry(
          id: 'r',
          name: 'SENT BACK',
          status: ApprovalStatus.rejected,
          reason: 'Photo is too dark',
        ),
      ]);

      expect(find.text('SENT BACK'), findsOneWidget);
      expect(
        find.text('Photo is too dark'),
        findsOneWidget,
        reason: 'a teacher must not have to open the card to learn why',
      );
    });

    testWidgets('hides Edit for an approved card', (WidgetTester tester) async {
      await _pumpEntries(tester, <StudentEntry>[
        _entry(id: 'a', name: 'LOCKED KID', status: ApprovalStatus.approved),
      ]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('View status'), findsOneWidget);
      expect(
        find.text('Edit'),
        findsNothing,
        reason: 'an approved card may already be printed and in a school',
      );
    });

    testWidgets('offers Edit for a rejected card', (WidgetTester tester) async {
      await _pumpEntries(tester, <StudentEntry>[
        _entry(id: 'r', name: 'FIXABLE', status: ApprovalStatus.rejected),
      ]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('empty state is specific to the active tab', (
      WidgetTester tester,
    ) async {
      await _pumpEntries(tester, <StudentEntry>[
        _entry(id: 'p', name: 'ONLY PENDING', status: ApprovalStatus.pending),
      ]);

      await tester.tap(find.text('Printed (0)'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing printed yet'), findsOneWidget);
    });
  });

  group('Request detail', () {
    testWidgets('leads with the admin remark when a card was sent back', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        _entry(
          id: 'r',
          name: 'SENT BACK',
          status: ApprovalStatus.rejected,
          reason: 'Name spelling does not match the register',
        ),
      );

      expect(find.text('Sent back by the office'), findsOneWidget);
      expect(
        find.text('Name spelling does not match the register'),
        findsOneWidget,
      );
      expect(find.text('Fix and resubmit'), findsOneWidget);
    });

    testWidgets('renders the four-step timeline', (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        _entry(id: 'a', name: 'KID', status: ApprovalStatus.approved),
      );

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Uploaded to the office'), findsOneWidget);
      expect(find.text('Reviewed by the office'), findsOneWidget);
      expect(find.text('Printed'), findsOneWidget);
    });

    testWidgets('locks editing once approved', (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        _entry(id: 'a', name: 'KID', status: ApprovalStatus.approved),
      );

      expect(find.text('Fix and resubmit'), findsNothing);
      expect(find.text('Edit details'), findsNothing);
      expect(find.textContaining('Approved cards are locked'), findsOneWidget);
    });

    testWidgets('shows the roll number in the header', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        _entry(id: 'x', name: 'KID', rollNumber: '12/A'),
      );

      expect(find.textContaining('Roll 12/A'), findsOneWidget);
    });

    testWidgets('says so when the entry is gone', (WidgetTester tester) async {
      await _pumpDetail(tester, null);
      expect(find.text('Submission not found'), findsOneWidget);
    });
  });

  group('Request id', () {
    test('is short enough to read out and stable across screens', () {
      const String uuid = '3f494a1f-4cfd-43d2-aaf3-0c7515b319bf';
      final String short = SubmissionSuccessScreen.shortId(uuid);

      expect(short, '3F494A');
      expect(short.length, 6);
      expect(short, short.toUpperCase());
    });

    test('does not crash on an id shorter than the window', () {
      expect(SubmissionSuccessScreen.shortId('abc'), 'ABC');
    });
  });

  group('ApprovalStatusChip', () {
    testWidgets('gives every status a distinct icon, not just a colour', (
      WidgetTester tester,
    ) async {
      final Set<IconData> icons = <IconData>{};
      for (final ApprovalStatus s in ApprovalStatus.values) {
        icons.add(ApprovalStatusChip.visualsFor(s).$2);
      }
      expect(
        icons.length,
        ApprovalStatus.values.length,
        reason: 'pending/approved are orange/green, which colour blindness '
            'collapses - the icon has to carry the meaning too',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<void> _pumpEntries(
  WidgetTester tester,
  List<StudentEntry> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entriesProvider.overrideWith(
          (ref) => Stream<List<StudentEntry>>.value(entries),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const SavedEntriesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(WidgetTester tester, StudentEntry? entry) async {
  // The detail screen is a tall scrolling column - header, remark, a four-step
  // timeline, details and actions. On the default 800x600 test surface the
  // actions card is below the fold and never built, so give it a phone-shaped
  // viewport tall enough to hold the whole thing.
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entriesProvider.overrideWith(
          (ref) => Stream<List<StudentEntry>>.value(
            entry == null ? const <StudentEntry>[] : <StudentEntry>[entry],
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: RequestDetailScreen(entryId: entry?.id ?? 'missing'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StudentEntry _entry({
  required String id,
  required String name,
  String rollNumber = '',
  ApprovalStatus status = ApprovalStatus.pending,
  String? reason,
}) {
  final DateTime now = DateTime(2026, 9, 9, 10, 30);
  return StudentEntry(
    id: id,
    schoolId: 'school-1',
    name: name,
    studentClass: '5',
    division: 'A',
    rollNumber: rollNumber,
    approvalStatus: status,
    rejectionReason: reason,
    // Synced so the timeline's upload step is not the active one, keeping
    // these assertions about the review step rather than the network.
    syncStatus: SyncStatus.synced,
    createdAt: now,
    updatedAt: now,
  );
}
