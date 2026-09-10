import 'package:drift/native.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the Plan-of-Action Phase 1 data model: roll number, the `printed`
/// approval state, and the `teacher` role.
void main() {
  group('Roll number field', () {
    test('is a first-class StudentField between division and blood group', () {
      const List<StudentField> order = StudentField.values;
      expect(
        order.indexOf(StudentField.rollNumber),
        greaterThan(order.indexOf(StudentField.division)),
        reason: 'roll number prints after division, per the card spec',
      );
      expect(
        order.indexOf(StudentField.rollNumber),
        lessThan(order.indexOf(StudentField.bloodGroup)),
      );
      expect(StudentField.rollNumber.key, 'rollNumber');
      expect(StudentField.rollNumber.cardLabel, 'ROLL NO');
      expect(
        StudentField.rollNumber.forceUppercase,
        isTrue,
        reason: 'register numbers like 12/a must print as 12/A',
      );
    });

    test('is readable generically by the card renderer', () {
      final StudentEntry entry = _entry(rollNumber: '12/A');
      expect(entry.valueOf(StudentField.rollNumber), '12/A');
    });

    test('survives a Firestore round trip', () {
      final StudentEntry entry = _entry(rollNumber: '0034');
      final StudentEntry back = StudentEntry.fromFirestoreMap(
        entry.id,
        entry.toFirestoreMap(),
      );
      expect(
        back.rollNumber,
        '0034',
        reason: 'a leading zero is meaningful and must not be dropped',
      );
    });

    test('is toggleable per school and included in the all-fields set', () {
      expect(StudentField.toggleable, contains(StudentField.rollNumber));
      expect(SchoolConfig.allFieldKeys, contains('rollNumber'));
    });
  });

  group('ApprovalStatus.printed', () {
    test('is printable so reprints do not need a status reset', () {
      expect(ApprovalStatus.printed.isPrintable, isTrue);
      expect(ApprovalStatus.approved.isPrintable, isTrue);
      expect(ApprovalStatus.pending.isPrintable, isFalse);
      expect(ApprovalStatus.rejected.isPrintable, isFalse);
    });

    test('is not awaiting review and needs no operator action', () {
      expect(ApprovalStatus.printed.awaitsReview, isFalse);
      expect(ApprovalStatus.printed.needsOperatorAttention, isFalse);
    });

    test('an unknown wire value still falls back to pending, not printed', () {
      expect(ApprovalStatus.fromName('something_new'), ApprovalStatus.pending);
      expect(ApprovalStatus.fromName(null), ApprovalStatus.pending);
      expect(ApprovalStatus.fromName('printed'), ApprovalStatus.printed);
    });
  });

  group('UserRole.teacher', () {
    test('parses from its wire value', () {
      expect(UserRole.fromWire('Teacher'), UserRole.teacher);
      expect(UserRole.fromWire('teacher'), UserRole.teacher);
    });

    test('is an operator, not an admin', () {
      expect(UserRole.teacher.isOperator, isTrue);
      expect(UserRole.school.isOperator, isTrue);
      expect(UserRole.admin.isOperator, isFalse);
    });

    test('an unrecognised role still degrades to school, never admin', () {
      expect(UserRole.fromWire('superuser'), UserRole.school);
      expect(UserRole.fromWire(null), UserRole.school);
    });
  });

  group('markPrinted', () {
    late AppDatabase db;
    late StudentRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = StudentRepository(db);
    });

    tearDown(() async => db.close());

    test('promotes only approved rows, and re-queues them for sync', () async {
      await repo.save(_entry(id: 'a', status: ApprovalStatus.approved));
      await repo.save(_entry(id: 'b', status: ApprovalStatus.pending));
      await repo.save(_entry(id: 'c', status: ApprovalStatus.rejected));

      final int moved = await repo.markPrinted(<String>['a', 'b', 'c']);

      expect(moved, 1, reason: 'only the approved row may become printed');

      final List<StudentEntry> all = await repo.listBySchool('school-1');
      final Map<String, StudentEntry> byId = <String, StudentEntry>{
        for (final StudentEntry e in all) e.id: e,
      };

      expect(byId['a']!.approvalStatus, ApprovalStatus.printed);
      expect(
        byId['a']!.syncStatus.name,
        'pending',
        reason: 'the teacher device must learn the card was printed',
      );
      expect(byId['b']!.approvalStatus, ApprovalStatus.pending);
      expect(byId['c']!.approvalStatus, ApprovalStatus.rejected);
    });

    test('is a no-op on an empty list', () async {
      expect(await repo.markPrinted(<String>[]), 0);
    });

    test('re-running a print batch does not double-move', () async {
      await repo.save(_entry(id: 'a', status: ApprovalStatus.approved));
      expect(await repo.markPrinted(<String>['a']), 1);
      expect(
        await repo.markPrinted(<String>['a']),
        0,
        reason: 'already printed, so nothing to promote on a reprint',
      );
    });
  });

  group('Schema migration', () {
    test('declares version 7', () {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 7);
    });

    test('stores and reads back a roll number', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final StudentRepository repo = StudentRepository(db);

      await repo.save(_entry(id: 'r1', rollNumber: '7/B'));
      final List<StudentEntry> all = await repo.listBySchool('school-1');

      expect(all.single.rollNumber, '7/B');
    });
  });
}

StudentEntry _entry({
  String id = 'e1',
  String rollNumber = '',
  ApprovalStatus status = ApprovalStatus.pending,
}) {
  final DateTime now = DateTime(2026, 9, 9);
  return StudentEntry(
    id: id,
    schoolId: 'school-1',
    name: 'TEST STUDENT',
    studentClass: '5',
    division: 'A',
    rollNumber: rollNumber,
    approvalStatus: status,
    createdAt: now,
    updatedAt: now,
  );
}
