import 'package:drift/native.dart';
import 'package:flutter_id_card/features/admin/data/csv_export_service.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/audit_repository.dart';
import 'package:flutter_id_card/shared/services/local/print_batch_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schema_version.dart';

void main() {
  group('Phase 4: CSV Export Service', () {
    test('buildCsvContent starts with UTF-8 BOM and headers', () {
      final String csv = CsvExportService.buildCsvContent(<StudentEntry>[]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv,
        contains(
          'Name,Father\'s Name,Class,Division,Blood Group,Date of Birth,Mobile,Address,Approval Status,Sync Status,Created At',
        ),
      );
    });

    test('buildCsvContent properly serializes student entry rows', () {
      final StudentEntry entry = StudentEntry(
        id: 's-1',
        schoolId: 'sch-1',
        name: 'John Doe',
        fatherName: 'Robert Doe',
        studentClass: '10',
        division: 'A',
        bloodGroup: 'O+',
        dob: DateTime(2010, 5, 15),
        mobile: '9876543210',
        address: '123 Main St, Springfield',
        approvalStatus: ApprovalStatus.approved,
        syncStatus: SyncStatus.synced,
        createdAt: DateTime(2026, 1, 1, 10, 0),
        updatedAt: DateTime(2026, 1, 1, 10, 0),
      );

      final String csv = CsvExportService.buildCsvContent(<StudentEntry>[entry]);
      expect(csv, contains('John Doe'));
      expect(csv, contains('Robert Doe'));
      expect(csv, contains('10,A,O+'));
      expect(csv, contains('"123 Main St, Springfield"'));
      expect(csv, contains('APPROVED'));
      expect(csv, contains('SYNCED'));
    });

    test('RFC 4180 escaping handles quotes, commas, and newlines', () {
      expect(CsvExportService.escapeField('Normal Text'), 'Normal Text');
      expect(CsvExportService.escapeField('Doe, John'), '"Doe, John"');
      expect(CsvExportService.escapeField('Quote "Here"'), '"Quote ""Here"""');
      expect(
        CsvExportService.escapeField('Line 1\nLine 2'),
        '"Line 1\nLine 2"',
      );
    });

    test('sanitiseFilename strips forbidden characters and cleans spaces', () {
      expect(
        CsvExportService.sanitiseFilename('School / Name : * Test ?'),
        'School_Name_Test',
      );
      expect(CsvExportService.sanitiseFilename('   '), 'Export');
      expect(CsvExportService.sanitiseFilename('St. Mary\'s High'), 'St._Mary\'s_High');
    });
  });

  group('Phase 4: Schema v5 & Audit Repository', () {
    late AppDatabase db;
    late AuditRepository auditRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      auditRepo = AuditRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('database schema version matches the declared constant', () {
      expect(db.schemaVersion, kExpectedSchemaVersion);
    });

    test('logs actions and retrieves via watchRecent and listForEntity', () async {
      await auditRepo.log(
        action: 'approve',
        entityType: 'student',
        entityId: 'student-123',
        actorUid: 'admin-1',
        details: <String, Object?>{'schoolId': 'sch-1', 'name': 'Alice'},
      );

      await auditRepo.log(
        action: 'export_csv',
        entityType: 'school',
        entityId: 'sch-1',
        actorUid: 'admin-1',
        details: <String, Object?>{'rowCount': 45},
      );

      final List<AuditEntry> recent = await auditRepo.watchRecent().first;
      expect(recent.length, 2);
      expect(recent.first.action, 'export_csv');
      expect(recent.first.actionLabel, 'CSV Exported');
      expect(recent.first.details['rowCount'], 45);

      expect(recent[1].action, 'approve');
      expect(recent[1].actionLabel, 'Approved');
      expect(recent[1].details['name'], 'Alice');

      final List<AuditEntry> studentHistory =
          await auditRepo.listForEntity('student', 'student-123');
      expect(studentHistory.length, 1);
      expect(studentHistory.first.entityId, 'student-123');
      expect(studentHistory.first.actorUid, 'admin-1');
    });

    test('watchByActions filters audit entries correctly', () async {
      await auditRepo.log(
        action: 'approve',
        entityType: 'student',
        entityId: 's1',
        actorUid: 'admin',
      );
      await auditRepo.log(
        action: 'reject',
        entityType: 'student',
        entityId: 's2',
        actorUid: 'admin',
      );
      await auditRepo.log(
        action: 'bulk_approve',
        entityType: 'student',
        entityId: 'sch1',
        actorUid: 'admin',
      );
      await auditRepo.log(
        action: 'print_batch',
        entityType: 'print_batch',
        entityId: 'pb1',
        actorUid: 'admin',
      );

      final List<AuditEntry> approvals = await auditRepo
          .watchByActions(<String>['approve', 'bulk_approve']).first;
      expect(approvals.length, 2);
      expect(
        approvals.map((AuditEntry a) => a.action),
        containsAll(<String>['approve', 'bulk_approve']),
      );

      final int rejectCount = await auditRepo.countByAction('reject');
      expect(rejectCount, 1);
    });
  });

  group('Phase 4: Print Batch Repository', () {
    late AppDatabase db;
    late PrintBatchRepository batchRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      batchRepo = PrintBatchRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates and queries print batches', () async {
      final DateTime now = DateTime.now();
      final String id1 = await batchRepo.create(
        schoolId: 'sch-1',
        cardCount: 25,
        sheetType: '12x18',
        sheetCount: 1,
        generatedBy: 'admin-uid',
        createdAt: now.subtract(const Duration(seconds: 10)),
      );

      final String id2 = await batchRepo.create(
        schoolId: 'sch-1',
        cardCount: 10,
        sheetType: 'a4',
        sheetCount: 1,
        generatedBy: 'admin-uid',
        createdAt: now,
      );

      await batchRepo.create(
        schoolId: 'sch-2',
        cardCount: 50,
        sheetType: 'single',
        sheetCount: 50,
        generatedBy: 'admin-uid',
        createdAt: now,
      );

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);

      final List<PrintBatch> sch1Batches =
          await batchRepo.watchBySchool('sch-1').first;
      expect(sch1Batches.length, 2);
      expect(sch1Batches.first.sheetTypeLabel, 'A4 Landscape');
      expect(sch1Batches[1].sheetTypeLabel, '12 × 18 in');

      final List<PrintBatch> allBatches = await batchRepo.watchAll().first;
      expect(allBatches.length, 3);

      final int cardCount = await batchRepo.cardCountForSchool('sch-1');
      expect(cardCount, 35);

      final int batchCount = await batchRepo.countForSchool('sch-1');
      expect(batchCount, 2);
    });
  });

  group('Phase 4: Student Repository Stale Sync Reset & Review Flow', () {
    late AppDatabase db;
    late StudentRepository studentRepo;
    late AuditRepository auditRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      studentRepo = StudentRepository(db);
      auditRepo = AuditRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('resetStaleSyncing resets entries older than threshold', () async {
      final StudentEntry staleEntry = StudentEntry(
        id: 'stale-1',
        schoolId: 'sch-1',
        name: 'Stale Student',
        fatherName: 'Father',
        studentClass: '5',
        division: 'B',
        bloodGroup: 'A+',
        mobile: '1234567890',
        address: 'Street',
        approvalStatus: ApprovalStatus.pending,
        syncStatus: SyncStatus.syncing,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      );

      await studentRepo.save(staleEntry);

      // Verify it was saved as syncing
      final StudentEntry? before = await studentRepo.findById('stale-1');
      expect(before?.syncStatus, SyncStatus.syncing);

      // Run resetStaleSyncing with 10 min threshold
      final int resetCount = await studentRepo.resetStaleSyncing(
        olderThan: const Duration(minutes: 10),
      );
      expect(resetCount, 1);

      final StudentEntry? after = await studentRepo.findById('stale-1');
      expect(after?.syncStatus, SyncStatus.pending);
    });

    test('approval workflow updates status and logs audit entry', () async {
      final StudentEntry entry = StudentEntry(
        id: 'rev-1',
        schoolId: 'sch-1',
        name: 'Review Candidate',
        fatherName: 'Parent',
        studentClass: '8',
        division: 'C',
        bloodGroup: 'B+',
        mobile: '9988776655',
        address: 'City',
        approvalStatus: ApprovalStatus.pending,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await studentRepo.save(entry);

      // Approve
      await studentRepo.approve('rev-1', reviewerUid: 'admin-reviewer');
      await auditRepo.log(
        action: 'approve',
        entityType: 'student',
        entityId: 'rev-1',
        actorUid: 'admin-reviewer',
        details: <String, Object?>{'schoolId': 'sch-1'},
      );

      final StudentEntry? approvedEntry = await studentRepo.findById('rev-1');
      expect(approvedEntry?.approvalStatus, ApprovalStatus.approved);
      expect(approvedEntry?.reviewedBy, 'admin-reviewer');
      expect(approvedEntry?.reviewedAt, isNotNull);

      final List<AuditEntry> auditList =
          await auditRepo.listForEntity('student', 'rev-1');
      expect(auditList.length, 1);
      expect(auditList.first.action, 'approve');
    });

    test('rejection workflow sets reason and logs audit entry', () async {
      final StudentEntry entry = StudentEntry(
        id: 'rev-2',
        schoolId: 'sch-1',
        name: 'Reject Candidate',
        fatherName: 'Parent',
        studentClass: '9',
        division: 'D',
        bloodGroup: 'AB+',
        mobile: '9988776655',
        address: 'City',
        approvalStatus: ApprovalStatus.pending,
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await studentRepo.save(entry);

      // Reject
      await studentRepo.reject(
        'rev-2',
        reviewerUid: 'admin-reviewer',
        reason: 'Photo is too dark',
      );
      await auditRepo.log(
        action: 'reject',
        entityType: 'student',
        entityId: 'rev-2',
        actorUid: 'admin-reviewer',
        details: <String, Object?>{
          'schoolId': 'sch-1',
          'reason': 'Photo is too dark',
        },
      );

      final StudentEntry? rejectedEntry = await studentRepo.findById('rev-2');
      expect(rejectedEntry?.approvalStatus, ApprovalStatus.rejected);
      expect(rejectedEntry?.rejectionReason, 'Photo is too dark');
      expect(rejectedEntry?.reviewedBy, 'admin-reviewer');

      final List<AuditEntry> auditList =
          await auditRepo.listForEntity('student', 'rev-2');
      expect(auditList.length, 1);
      expect(auditList.first.action, 'reject');
      expect(auditList.first.details['reason'], 'Photo is too dark');
    });
  });
}
