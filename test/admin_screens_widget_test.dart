import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/admin_users_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/audit_log_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/export_screen.dart';
import 'package:flutter_id_card/features/admin/presentation/school_detail_screen.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/managed_user.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/audit_repository.dart';
import 'package:flutter_id_card/shared/services/local/print_batch_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SchoolConfig testSchool = SchoolConfig(
    id: 'sch-test',
    name: 'Test Academy',
    addressLine: '100 Learning Ave',
    headerColorHex: 0xFF1565C0,
    classes: <String>['10', '11', '12'],
    divisions: <String>['A', 'B'],
    cardSizeId: 'v54x86',
  );

  final StudentEntry testEntry = StudentEntry(
    id: 'std-1',
    schoolId: 'sch-test',
    name: 'Jane Doe',
    fatherName: 'John Doe',
    studentClass: '10',
    division: 'A',
    bloodGroup: 'B+',
    mobile: '9876543210',
    address: 'Test City',
    approvalStatus: ApprovalStatus.pending,
    syncStatus: SyncStatus.pending,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final PrintBatch testBatch = PrintBatch(
    id: 'pb-1',
    schoolId: 'sch-test',
    cardCount: 20,
    sheetType: 'a4',
    sheetCount: 2,
    generatedBy: 'admin-tester',
    createdAt: DateTime(2026, 1, 1),
  );

  final AuditEntry testAudit = AuditEntry(
    id: 1,
    action: 'export_csv',
    entityType: 'school',
    entityId: 'sch-test',
    actorUid: 'admin-tester',
    details: const <String, Object?>{'rowCount': 15},
    createdAt: DateTime(2026, 1, 1),
  );

  group('Admin Dashboard Screen Widget Tests', () {
    testWidgets('renders AdminDashboardScreen with audit and user management links',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allSchoolsProvider.overrideWith((ref) => Stream.value([testSchool])),
            allEntriesProvider.overrideWith((ref) => Stream.value([testEntry])),
            adminStatsProvider.overrideWithValue(
              const AsyncValue.data(
                AdminStats(schools: 1, total: 1, awaitingReview: 1),
              ),
            ),
            currentSessionProvider.overrideWithValue(
              const SessionUser(
                uid: 'admin-tester',
                role: UserRole.admin,
                email: 'admin@test.com',
              ),
            ),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Admin Panel'), findsOneWidget);
      // Twice now: once beside the entry in Latest requests, once in the
      // school list below it.
      expect(find.text('Test Academy'), findsWidgets);

      // The three verbose navigation cards were replaced by a compact quick
      // actions grid, so the dashboard leads with the backlog instead of a
      // wall of link cards.
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Audit log'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Bulk message'), findsOneWidget);

      // One entry is awaiting review, so the callout is the first thing shown.
      expect(find.text('awaiting review'), findsOneWidget);
      expect(find.text('Latest requests'), findsOneWidget);
    });
  });

  group('School Detail Screen Widget Tests', () {
    testWidgets('renders SchoolDetailScreen with Export and Print History actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolByIdProvider('sch-test')
                .overrideWith((ref) => Stream.value(testSchool)),
            entriesForSchoolProvider('sch-test')
                .overrideWith((ref) => Stream.value([testEntry])),
            printBatchesForSchoolProvider('sch-test')
                .overrideWith((ref) => Stream.value([testBatch])),
            currentSessionProvider.overrideWithValue(
              const SessionUser(
                uid: 'admin-tester',
                role: UserRole.admin,
                email: 'admin@test.com',
              ),
            ),
          ],
          child: const MaterialApp(
            home: SchoolDetailScreen(schoolId: 'sch-test'),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Test Academy'), findsOneWidget);
      expect(find.byTooltip('Export CSV & Reports'), findsOneWidget);
      expect(find.byTooltip('Print history'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);

      // Open Print History bottom sheet
      await tester.tap(find.byTooltip('Print history'));
      await tester.pumpAndSettle();

      expect(find.text('Print Run History'), findsOneWidget);
      expect(find.text('20 cards · A4 Landscape'), findsOneWidget);
    });
  });

  group('Export Screen Widget Tests', () {
    testWidgets('renders ExportScreen with filter options and batches',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolByIdProvider('sch-test')
                .overrideWith((ref) => Stream.value(testSchool)),
            entriesForSchoolProvider('sch-test')
                .overrideWith((ref) => Stream.value([testEntry])),
            printBatchesForSchoolProvider('sch-test')
                .overrideWith((ref) => Stream.value([testBatch])),
            currentSessionProvider.overrideWithValue(
              const SessionUser(
                uid: 'admin-tester',
                role: UserRole.admin,
                email: 'admin@test.com',
              ),
            ),
          ],
          child: const MaterialApp(
            home: ExportScreen(schoolId: 'sch-test'),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Export & Reports'), findsOneWidget);
      expect(find.text('CSV Export'), findsOneWidget);
      expect(find.text('Print Batch History'), findsOneWidget);
      expect(find.text('20 cards · A4 Landscape'), findsOneWidget);

      // Verify filter chips
      expect(find.widgetWithText(FilterChip, 'All'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'Approved'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Pending'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Rejected'), findsOneWidget);
    });
  });

  group('Audit Log Screen Widget Tests', () {
    testWidgets('renders AuditLogScreen and displays action entries',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentAuditLogsProvider
                .overrideWith((ref) => Stream.value([testAudit])),
            auditLogsByActionsProvider(const <String>['export_csv'])
                .overrideWith((ref) => Stream.value([testAudit])),
          ],
          child: const MaterialApp(home: AuditLogScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Audit Log'), findsOneWidget);
      expect(find.text('CSV Exported'), findsOneWidget);
      expect(find.text('Exports'), findsOneWidget);
      expect(find.text('Print Batches'), findsOneWidget);

      // Tap on the entry to expand JSON details
      await tester.tap(find.text('CSV Exported'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"rowCount": 15'), findsOneWidget);
    });
  });

  group('Admin Users Screen Widget Tests', () {
    testWidgets('renders AdminUsersScreen with operator accounts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allUsersProvider.overrideWith(
              (ref) => Stream.value(
                const <ManagedUser>[
                  ManagedUser(
                    uid: 'u1',
                    email: 'sch01@test.com',
                    displayName: 'SCH01',
                    role: UserRole.school,
                    schoolId: 'sch-1',
                    active: true,
                  ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(
            home: AdminUsersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('SCH01'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
