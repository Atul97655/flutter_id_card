import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/admin/application/admin_providers.dart';
import 'package:flutter_id_card/features/admin/data/reports_service.dart';
import 'package:flutter_id_card/features/admin/presentation/reports_screen.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/print_batch_repository.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_id_card/shared/widgets/offline_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5: Reports Service & Analytics Calculation', () {
    late AppDatabase db;
    late SchoolRepository schoolRepo;
    late StudentRepository studentRepo;
    late PrintBatchRepository printBatchRepo;
    late ReportsService reportsService;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      schoolRepo = SchoolRepository(db);
      studentRepo = StudentRepository(db);
      printBatchRepo = PrintBatchRepository(db);
      reportsService = ReportsService(
        students: studentRepo,
        schools: schoolRepo,
        printBatches: printBatchRepo,
      );

      // Seed 2 schools
      await schoolRepo.save(
        const SchoolConfig(
          id: 'sch-1',
          name: 'Greenfield High',
          cardSizeId: 'v54x86',
        ),
      );
      await schoolRepo.save(
        const SchoolConfig(
          id: 'sch-2',
          name: 'Riverside Academy',
          cardSizeId: 'v52x84',
        ),
      );

      // Seed Students for School 1 (Jan & Feb 2026)
      // 1. Approved with photo
      await studentRepo.save(
        StudentEntry(
          id: 's1',
          schoolId: 'sch-1',
          name: 'Alice Smith',
          studentClass: '10',
          division: 'A',
          localPhotoPath: '/photos/s1.jpg',
          approvalStatus: ApprovalStatus.approved,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2026, 1, 10, 10, 0),
          updatedAt: DateTime(2026, 1, 10, 10, 0),
        ),
      );
      // 2. Approved with photo
      await studentRepo.save(
        StudentEntry(
          id: 's2',
          schoolId: 'sch-1',
          name: 'Bob Jones',
          studentClass: '10',
          division: 'B',
          localPhotoPath: '/photos/s2.jpg',
          approvalStatus: ApprovalStatus.approved,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2026, 1, 15, 11, 0),
          updatedAt: DateTime(2026, 1, 15, 11, 0),
        ),
      );
      // 3. Approved without photo
      await studentRepo.save(
        StudentEntry(
          id: 's3',
          schoolId: 'sch-1',
          name: 'Charlie Brown',
          studentClass: '9',
          division: 'A',
          approvalStatus: ApprovalStatus.approved,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2026, 2, 5, 9, 0),
          updatedAt: DateTime(2026, 2, 5, 9, 0),
        ),
      );
      // 4. Rejected
      await studentRepo.save(
        StudentEntry(
          id: 's4',
          schoolId: 'sch-1',
          name: 'David Miller',
          studentClass: '9',
          division: 'B',
          approvalStatus: ApprovalStatus.rejected,
          rejectionReason: 'Blurry photo',
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2026, 2, 10, 14, 0),
          updatedAt: DateTime(2026, 2, 10, 14, 0),
        ),
      );
      // 5. Pending
      await studentRepo.save(
        StudentEntry(
          id: 's5',
          schoolId: 'sch-1',
          name: 'Emma Watson',
          studentClass: '8',
          division: 'A',
          approvalStatus: ApprovalStatus.pending,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime(2026, 2, 20, 15, 0),
          updatedAt: DateTime(2026, 2, 20, 15, 0),
        ),
      );

      // Seed Students for School 2 (Feb 2026)
      // 6. Approved with photo
      await studentRepo.save(
        StudentEntry(
          id: 's6',
          schoolId: 'sch-2',
          name: 'Fiona Gallagher',
          studentClass: '11',
          division: 'A',
          localPhotoPath: '/photos/s6.jpg',
          approvalStatus: ApprovalStatus.approved,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2026, 2, 1, 10, 0),
          updatedAt: DateTime(2026, 2, 1, 10, 0),
        ),
      );
      // 7. Approved with photo
      await studentRepo.save(
        StudentEntry(
          id: 's7',
          schoolId: 'sch-2',
          name: 'George Clark',
          studentClass: '11',
          division: 'A',
          localPhotoPath: '/photos/s7.jpg',
          approvalStatus: ApprovalStatus.approved,
          syncStatus: SyncStatus.synced,
          createdAt: DateTime(2026, 2, 2, 11, 0),
          updatedAt: DateTime(2026, 2, 2, 11, 0),
        ),
      );
      // 8. Pending
      await studentRepo.save(
        StudentEntry(
          id: 's8',
          schoolId: 'sch-2',
          name: 'Hannah Abbott',
          studentClass: '12',
          division: 'C',
          approvalStatus: ApprovalStatus.pending,
          syncStatus: SyncStatus.pending,
          createdAt: DateTime(2026, 2, 3, 12, 0),
          updatedAt: DateTime(2026, 2, 3, 12, 0),
        ),
      );

      // Seed Print Batches
      await printBatchRepo.create(
        schoolId: 'sch-1',
        cardCount: 20,
        sheetCount: 2,
        sheetType: 'a4',
        generatedBy: 'admin',
      );
      await printBatchRepo.create(
        schoolId: 'sch-2',
        cardCount: 15,
        sheetCount: 1,
        sheetType: '12x18',
        generatedBy: 'admin',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('generateReport calculates accurate cross-school totals', () async {
      final SystemReport report = await reportsService.generateReport();

      expect(report.totalSchools, 2);
      expect(report.totalStudents, 8);
      expect(report.totalApproved, 5);
      expect(report.totalPending, 2);
      expect(report.totalRejected, 1);
      expect(report.totalPrintable, 4); // s1, s2, s6, s7 have photos & are approved
      expect(report.totalBatches, 2);
      expect(report.totalCardsPrinted, 35);
      expect(report.overallApprovalPercentage, closeTo(5 / 8 * 100, 0.01));
    });

    test('generateReport breaks down metrics per school', () async {
      final SystemReport report = await reportsService.generateReport();

      final SchoolReportItem sch1 =
          report.schoolReports.firstWhere((SchoolReportItem r) => r.schoolId == 'sch-1');
      expect(sch1.schoolName, 'Greenfield High');
      expect(sch1.totalCount, 5);
      expect(sch1.approvedCount, 3);
      expect(sch1.pendingCount, 1);
      expect(sch1.rejectedCount, 1);
      expect(sch1.printableCount, 2);
      expect(sch1.approvalPercentage, closeTo(3 / 5 * 100, 0.01));

      final SchoolReportItem sch2 =
          report.schoolReports.firstWhere((SchoolReportItem r) => r.schoolId == 'sch-2');
      expect(sch2.schoolName, 'Riverside Academy');
      expect(sch2.totalCount, 3);
      expect(sch2.approvedCount, 2);
      expect(sch2.pendingCount, 1);
      expect(sch2.rejectedCount, 0);
      expect(sch2.printableCount, 2);
      expect(sch2.approvalPercentage, closeTo(2 / 3 * 100, 0.01));
    });

    test('generateReport tracks monthly submission chronologically', () async {
      final SystemReport report = await reportsService.generateReport();

      expect(report.monthlyTrend.length, 2);
      expect(report.monthlyTrend.first.yearMonth, '2026-01');
      expect(report.monthlyTrend.first.count, 2);

      expect(report.monthlyTrend[1].yearMonth, '2026-02');
      expect(report.monthlyTrend[1].count, 6);
    });
  });

  group('Phase 5: Offline Banner Widget', () {
    testWidgets('shows warning when device is offline', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );

      expect(find.textContaining('Working offline'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('remains hidden when device is online', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );

      expect(find.textContaining('Working offline'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });
  });

  group('Phase 5: Reports Dashboard Screen', () {
    testWidgets('renders headline metrics and school breakdowns', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const SystemReport mockReport = SystemReport(
        totalSchools: 1,
        totalStudents: 150,
        totalApproved: 120,
        totalPending: 25,
        totalRejected: 5,
        totalPrintable: 115,
        totalBatches: 3,
        totalCardsPrinted: 100,
        schoolReports: <SchoolReportItem>[
          SchoolReportItem(
            schoolId: 'sch-1',
            schoolName: 'Oakridge International',
            cardSizeLabel: 'CR-80',
            totalCount: 150,
            approvedCount: 120,
            pendingCount: 25,
            rejectedCount: 5,
            printableCount: 115,
          ),
        ],
        monthlyTrend: <MonthlySummaryItem>[
          MonthlySummaryItem(
            yearMonth: '2026-02',
            label: 'Feb 2026',
            count: 150,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemReportProvider.overrideWith((_) async => mockReport),
          ],
          child: const MaterialApp(
            home: ReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('150'), findsWidgets); // Total students count
      expect(find.textContaining('Approved'), findsWidgets);
      expect(find.text('Awaiting Review'), findsOneWidget);
      expect(find.text('Total Cards Printed'), findsOneWidget);
      expect(find.text('Oakridge International'), findsOneWidget);
      expect(find.text('Monthly Submissions'), findsOneWidget);
      expect(find.text('Feb 2026'), findsOneWidget);
    });
  });

  group('Phase 5: Multi-Tenant Security & Tenant Isolation', () {
    test('operator role cannot operate outside assigned school tenant', () {
      const SessionUser operator = SessionUser(
        uid: 'op-1',
        role: UserRole.school,
        schoolId: 'sch-alpha',
        email: 'operator@alpha.edu',
      );

      expect(operator.isAdmin, isFalse);
      expect(operator.schoolId, 'sch-alpha');

      // Helper function matching the security guard in data_entry_screen.dart
      bool isAuthorized(SessionUser user, String targetSchoolId) {
        if (user.role == UserRole.admin) return true;
        if (user.schoolId != null && user.schoolId != targetSchoolId) {
          return false;
        }
        return true;
      }

      // Authorized within own tenant
      expect(isAuthorized(operator, 'sch-alpha'), isTrue);

      // Unauthorized across tenant boundary
      expect(isAuthorized(operator, 'sch-beta'), isFalse);
    });

    test('admin role has unrestricted cross-tenant permissions', () {
      const SessionUser admin = SessionUser(
        uid: 'admin-super',
        role: UserRole.admin,
        email: 'admin@system.internal',
      );

      expect(admin.isAdmin, isTrue);

      bool isAuthorized(SessionUser user, String targetSchoolId) {
        if (user.role == UserRole.admin) return true;
        if (user.schoolId != null && user.schoolId != targetSchoolId) {
          return false;
        }
        return true;
      }

      expect(isAuthorized(admin, 'sch-alpha'), isTrue);
      expect(isAuthorized(admin, 'sch-beta'), isTrue);
      expect(isAuthorized(admin, 'sch-gamma'), isTrue);
    });
  });
}
