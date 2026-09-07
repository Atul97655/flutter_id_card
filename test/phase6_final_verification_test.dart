import 'package:drift/native.dart';
import 'package:flutter_id_card/features/admin/data/csv_export_service.dart';
import 'package:flutter_id_card/features/admin/data/reports_service.dart';
import 'package:flutter_id_card/features/admin/domain/imposition.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/print/print_units.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/audit_repository.dart';
import 'package:flutter_id_card/shared/services/local/print_batch_repository.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_id_card/shared/utils/input_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 6: Print Calibration & Imposition Geometry (300 DPI Specs)', () {
    test('Card dimensions adhere strictly to 54 x 86 mm specification', () {
      const CardSize size = CardSize.v54x86;
      expect(size.widthMm, 54.0);
      expect(size.heightMm, 86.0);
      expect(size.orientation, CardOrientation.vertical);

      // Verify conversion to PDF typographic points
      final double widthPt = PrintUnits.mmToPt(size.widthMm);
      final double heightPt = PrintUnits.mmToPt(size.heightMm);
      expect(widthPt, closeTo(54.0 / 25.4 * 72.0, 0.001));
      expect(heightPt, closeTo(86.0 / 25.4 * 72.0, 0.001));

      // Verify 300 DPI pixel dimensions
      final double widthPx = PrintUnits.mmToPx(size.widthMm, dpi: 300.0);
      final double heightPx = PrintUnits.mmToPx(size.heightMm, dpi: 300.0);
      expect(widthPx.round(), 638); // 54 / 25.4 * 300 ≈ 637.79
      expect(heightPx.round(), 1016); // 86 / 25.4 * 300 ≈ 1015.75
    });

    test('Student photo dimensions adhere to 1.2 x 1.5 inch specification', () {
      expect(PhotoSpec.widthInch, 1.2);
      expect(PhotoSpec.heightInch, 1.5);
      expect(PhotoSpec.widthMm, closeTo(30.48, 0.01));
      expect(PhotoSpec.heightMm, closeTo(38.10, 0.01));
      expect(PhotoSpec.widthPx, 360); // 1.2 * 300 = 360 px
      expect(PhotoSpec.heightPx, 450); // 1.5 * 300 = 450 px
    });

    test('A4 Landscape sheet computes exactly 10 cards (5 columns x 2 rows)', () {
      const SheetSpec sheet = SheetSpec.a4Landscape;
      expect(sheet.widthMm, 297.0);
      expect(sheet.heightMm, 210.0);

      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: sheet,
        cardSize: CardSize.v54x86,
      );

      expect(grid.columns, 5);
      expect(grid.rows, 2);
      expect(grid.capacity, 10);
      expect(grid.isUsable, isTrue);
      expect(grid.marginLeftMm, greaterThan(0));
      expect(grid.marginTopMm, greaterThan(0));
    });

    test('12 x 18 in sheet computes exactly 25 cards (5 columns x 5 rows)', () {
      const SheetSpec sheet = SheetSpec.sheet12x18;
      expect(sheet.widthMm, 304.8);
      expect(sheet.heightMm, 457.2);

      final ImpositionGrid grid = ImpositionGrid.compute(
        sheet: sheet,
        cardSize: CardSize.v54x86,
      );

      expect(grid.columns, 5);
      expect(grid.rows, 5);
      expect(grid.capacity, 25);
      expect(grid.isUsable, isTrue);
      expect(grid.marginLeftMm, greaterThan(0));
      expect(grid.marginTopMm, greaterThan(0));
    });
  });

  group('Phase 6: Data Integrity & Uppercase Conversion', () {
    test('UpperCaseTextInputFormatter automatically converts lowercase to uppercase', () {
      const UpperCaseTextInputFormatter formatter = UpperCaseTextInputFormatter();
      const TextEditingValue oldValue = TextEditingValue.empty;

      final TextEditingValue result1 = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: 'robert john'),
      );
      expect(result1.text, 'ROBERT JOHN');

      final TextEditingValue result2 = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: '123 main street, suite 4b'),
      );
      expect(result2.text, '123 MAIN STREET, SUITE 4B');
    });
  });

  group('Phase 6: Full End-to-End System Regression', () {
    late AppDatabase db;
    late SchoolRepository schoolRepo;
    late StudentRepository studentRepo;
    late PrintBatchRepository printBatchRepo;
    late AuditRepository auditRepo;
    late ReportsService reportsService;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      schoolRepo = SchoolRepository(db);
      studentRepo = StudentRepository(db);
      printBatchRepo = PrintBatchRepository(db);
      auditRepo = AuditRepository(db);
      reportsService = ReportsService(
        students: studentRepo,
        schools: schoolRepo,
        printBatches: printBatchRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('complete lifecycle: school creation, student review, print, export, audit & reports',
        () async {
      // 1. Create School
      const SchoolConfig school = SchoolConfig(
        id: 'sch-final',
        name: 'ST. XAVIER HIGH SCHOOL',
        cardSizeId: 'v54x86',
        primaryColorHex: 0xFFD32F2F,
        secondaryColorHex: 0xFF1565C0,
        classes: <String>['1', '2', '3', '10'],
        divisions: <String>['A', 'B', 'C'],
      );
      await schoolRepo.save(school);
      final SchoolConfig? fetchedSchool = await schoolRepo.find('sch-final');
      expect(fetchedSchool, isNotNull);
      expect(fetchedSchool!.name, 'ST. XAVIER HIGH SCHOOL');

      // 2. Submit Student Entries
      final DateTime now = DateTime(2026, 3, 1, 10, 0);
      final StudentEntry s1 = StudentEntry(
        id: 'std-1',
        schoolId: 'sch-final',
        name: 'AARAV SHARMA',
        fatherName: 'RAJESH SHARMA',
        studentClass: '10',
        division: 'A',
        bloodGroup: 'B+',
        dob: DateTime(2010, 8, 15),
        mobile: '9876543210',
        address: 'CIVIL LINES, SECTOR 4',
        localPhotoPath: '/photos/aarav.png',
        approvalStatus: ApprovalStatus.pending,
        syncStatus: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
      );
      final StudentEntry s2 = StudentEntry(
        id: 'std-2',
        schoolId: 'sch-final',
        name: 'PRIYA PATEL',
        fatherName: 'SURESH PATEL',
        studentClass: '10',
        division: 'B',
        bloodGroup: 'O+',
        dob: DateTime(2011, 2, 20),
        mobile: '9876543211',
        address: 'LINK ROAD, NEAR STATION',
        localPhotoPath: '/photos/priya.png',
        approvalStatus: ApprovalStatus.pending,
        syncStatus: SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
      );
      await studentRepo.save(s1);
      await studentRepo.save(s2);

      expect((await studentRepo.listBySchool('sch-final')).length, 2);

      // 3. Admin Reviews & Approves Entries
      await studentRepo.approveAll(<String>['std-1', 'std-2'], reviewerUid: 'admin-1');
      await auditRepo.log(
        action: 'bulk_approve',
        entityType: 'student',
        entityId: 'sch-final',
        actorUid: 'admin-1',
        details: <String, Object?>{'count': 2},
      );

      final StudentEntry? approvedS1 = await studentRepo.findById('std-1');
      expect(approvedS1!.approvalStatus, ApprovalStatus.approved);
      expect(approvedS1.reviewedBy, 'admin-1');

      // 4. Generate Print Batch
      final String batchId = await printBatchRepo.create(
        schoolId: 'sch-final',
        cardCount: 2,
        sheetCount: 1,
        sheetType: 'a4',
        generatedBy: 'admin-1',
      );
      expect(batchId.isNotEmpty, isTrue);

      await auditRepo.log(
        action: 'print_batch',
        entityType: 'print_batch',
        entityId: batchId,
        actorUid: 'admin-1',
        details: <String, Object?>{'sheetType': 'a4', 'cardCount': 2},
      );

      // 5. Export CSV
      final List<StudentEntry> toExport = await studentRepo.listBySchool('sch-final');
      final String csv = CsvExportService.buildCsvContent(toExport);
      expect(csv.startsWith('\uFEFF'), isTrue); // UTF-8 BOM
      expect(csv, contains('AARAV SHARMA'));
      expect(csv, contains('PRIYA PATEL'));

      await auditRepo.log(
        action: 'export_csv',
        entityType: 'school',
        entityId: 'sch-final',
        actorUid: 'admin-1',
        details: <String, Object?>{'rows': 2},
      );

      // 6. Verify Audit Logs
      final List<AuditEntry> logs = await auditRepo.watchRecent().first;
      expect(logs.length, 3);
      expect(logs.map((AuditEntry l) => l.action),
          containsAll(<String>['bulk_approve', 'print_batch', 'export_csv']));

      // 7. Verify Reports Service Aggregation
      final SystemReport report = await reportsService.generateReport();
      expect(report.totalSchools, 1);
      expect(report.totalStudents, 2);
      expect(report.totalApproved, 2);
      expect(report.totalPrintable, 2);
      expect(report.totalCardsPrinted, 2);
      expect(report.overallApprovalPercentage, 100.0);
    });
  });
}
