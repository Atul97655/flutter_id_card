import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_id_card/features/auth/data/auth_repository.dart';
import 'package:flutter_id_card/features/auth/domain/managed_user.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Principal Signature & Template Parsing', () {
    test('parses signature element from template JSON', () {
      final String jsonStr = jsonEncode(<String, Object?>{
        'id': 'test_template',
        'name': 'Test Template',
        'cardSizeId': 'v54x86',
        'elements': <Map<String, Object?>>[
          <String, Object?>{
            'type': 'signature',
            'x': 30.0,
            'y': 72.0,
            'w': 18.0,
            'h': 5.5,
          },
        ],
      });

      final CardTemplate template =
          CardTemplate.fromJson(jsonDecode(jsonStr) as Map<String, Object?>);
      expect(template.elements.length, 1);
      final CardElement el = template.elements.first;
      expect(el, isA<SignatureElement>());
      final SignatureElement sig = el as SignatureElement;
      expect(sig.xMm, 30.0);
      expect(sig.yMm, 72.0);
      expect(sig.widthMm, 18.0);
      expect(sig.heightMm, 5.5);
    });

    test('SchoolConfig stores and persists principalSignature paths in Drift', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final SchoolRepository repo = SchoolRepository(db);

      const SchoolConfig config = SchoolConfig(
        id: 'test_school',
        name: 'TEST SCHOOL',
        localLogoPath: '/path/to/logo.png',
        localPrincipalSignaturePath: '/path/to/signature.png',
        principalSignatureUrl: 'https://storage.googleapis.com/test_sig.png',
      );

      await repo.save(config);
      final SchoolConfig? loaded = await repo.find('test_school');

      expect(loaded, isNotNull);
      expect(loaded!.localPrincipalSignaturePath, '/path/to/signature.png');
      expect(loaded.principalSignatureUrl, 'https://storage.googleapis.com/test_sig.png');
      expect(loaded.localLogoPath, '/path/to/logo.png');
    });
  });

  group('Phase 3: Submissions Bulk Reject & Duplicate Detection', () {
    late AppDatabase db;
    late StudentRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = StudentRepository(db);
    });

    tearDown(() => db.close());

    StudentEntry createStudent({
      required String id,
      required String name,
      required String studentClass,
      required String division,
      DateTime? dob,
    }) {
      return StudentEntry(
        id: id,
        schoolId: 'sch1',
        name: name,
        studentClass: studentClass,
        division: division,
        dob: dob,
        syncStatus: SyncStatus.pending,
        approvalStatus: ApprovalStatus.pending,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    }

    test('rejectAll marks multiple entries as rejected with a reason', () async {
      await repo.saveAll(<StudentEntry>[
        createStudent(id: 's1', name: 'AARAV PATEL', studentClass: '10', division: 'A'),
        createStudent(id: 's2', name: 'DIYA SHARMA', studentClass: '10', division: 'A'),
        createStudent(id: 's3', name: 'ROHAN VERMA', studentClass: '10', division: 'A'),
      ]);

      await repo.rejectAll(
        <String>['s1', 's2'],
        reviewerUid: 'admin-1',
        reason: 'Photo background is not plain white',
      );

      final StudentEntry? s1 = await repo.findById('s1');
      final StudentEntry? s2 = await repo.findById('s2');
      final StudentEntry? s3 = await repo.findById('s3');

      expect(s1!.approvalStatus, ApprovalStatus.rejected);
      expect(s1.rejectionReason, 'Photo background is not plain white');
      expect(s1.reviewedBy, 'admin-1');

      expect(s2!.approvalStatus, ApprovalStatus.rejected);
      expect(s2.rejectionReason, 'Photo background is not plain white');

      expect(s3!.approvalStatus, ApprovalStatus.pending);
      expect(s3.rejectionReason, isNull);
    });

    test('findPotentialDuplicates catches matching name and class in same school', () async {
      final DateTime dob = DateTime(2010, 5, 15);
      await repo.save(
        createStudent(id: 'orig', name: 'ANANYA SEN', studentClass: '9', division: 'B', dob: dob),
      );

      // Exact match
      final List<StudentEntry> dupes1 = await repo.findPotentialDuplicates(
        schoolId: 'sch1',
        name: 'ANANYA SEN',
        studentClass: '9',
        dob: dob,
      );
      expect(dupes1.length, 1);
      expect(dupes1.first.id, 'orig');

      // Exclude self during update
      final List<StudentEntry> dupesSelf = await repo.findPotentialDuplicates(
        schoolId: 'sch1',
        name: 'ANANYA SEN',
        studentClass: '9',
        dob: dob,
        excludeId: 'orig',
      );
      expect(dupesSelf, isEmpty);

      // Different class -> no duplicate
      final List<StudentEntry> dupesDiffClass = await repo.findPotentialDuplicates(
        schoolId: 'sch1',
        name: 'ANANYA SEN',
        studentClass: '10',
      );
      expect(dupesDiffClass, isEmpty);

      // Different school -> no duplicate
      final List<StudentEntry> dupesDiffSchool = await repo.findPotentialDuplicates(
        schoolId: 'sch2',
        name: 'ANANYA SEN',
        studentClass: '9',
      );
      expect(dupesDiffSchool, isEmpty);
    });
  });

  group('Phase 3: User Management & Access Control', () {
    test('ManagedUser serializes and deserializes accurately', () {
      final DateTime now = DateTime.now();
      final ManagedUser user = ManagedUser(
        uid: 'user-123',
        email: 'test@schools.idcardx.app',
        role: UserRole.school,
        schoolId: 'test_school',
        displayName: 'Test Operator',
        active: true,
        createdAt: now,
      );

      final Map<String, Object?> json = user.toJson();
      final ManagedUser restored = ManagedUser.fromJson(json);

      expect(restored.uid, 'user-123');
      expect(restored.email, 'test@schools.idcardx.app');
      expect(restored.role, UserRole.school);
      expect(restored.schoolId, 'test_school');
      expect(restored.displayName, 'Test Operator');
      expect(restored.active, isTrue);
    });

    test('AuthRepository creates user and toggles active access', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AuthRepository authRepo = AuthRepository();

      await authRepo.createUserAccount(
        email: 'opschool',
        password: 'password123',
        role: UserRole.school,
        schoolId: 'opschool',
        displayName: 'Operator One',
      );

      final List<ManagedUser> users = await authRepo.watchUsers().first;
      expect(users.any((ManagedUser u) => u.displayName == 'Operator One'), isTrue);

      final ManagedUser created =
          users.firstWhere((ManagedUser u) => u.displayName == 'Operator One');
      expect(created.active, isTrue);

      // Disable access
      await authRepo.toggleUserActive(created.uid, false);
      final List<ManagedUser> updatedUsers = await authRepo.watchUsers().first;
      final ManagedUser disabled =
          updatedUsers.firstWhere((ManagedUser u) => u.uid == created.uid);
      expect(disabled.active, isFalse);

      // Re-enable access
      await authRepo.toggleUserActive(created.uid, true);
      final List<ManagedUser> reenabledUsers = await authRepo.watchUsers().first;
      final ManagedUser reenabled =
          reenabledUsers.firstWhere((ManagedUser u) => u.uid == created.uid);
      expect(reenabled.active, isTrue);
    });
  });
}
