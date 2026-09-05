import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_id_card/features/admin/domain/imposition.dart';
import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/application/imposition_service.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/card_size.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

StudentEntry entry({
  String id = 'e1',
  String name = 'RAMESH KUMAR',
  ApprovalStatus approval = ApprovalStatus.pending,
  String? photo = '/tmp/photo.png',
}) {
  return StudentEntry(
    id: id,
    schoolId: 's1',
    name: name,
    studentClass: '10',
    division: 'A',
    mobile: '9876543210',
    localPhotoPath: photo,
    approvalStatus: approval,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApprovalStatus', () {
    test('only approved is printable', () {
      expect(ApprovalStatus.approved.isPrintable, isTrue);
      expect(ApprovalStatus.pending.isPrintable, isFalse);
      expect(ApprovalStatus.rejected.isPrintable, isFalse);
    });

    test('an unknown status decays to pending, never to approved', () {
      // The safe direction: a status written by a newer build must never let
      // something unreviewed slip into a print run.
      expect(ApprovalStatus.fromName('somethingNew'), ApprovalStatus.pending);
      expect(ApprovalStatus.fromName(null), ApprovalStatus.pending);
      expect(ApprovalStatus.fromName(''), ApprovalStatus.pending);
    });

    test('round-trips through its wire name', () {
      for (final ApprovalStatus s in ApprovalStatus.values) {
        expect(ApprovalStatus.fromName(s.name), s);
      }
    });

    test('rejected is what the operator must act on', () {
      expect(ApprovalStatus.rejected.needsOperatorAttention, isTrue);
      expect(ApprovalStatus.pending.needsOperatorAttention, isFalse);
    });
  });

  group('StudentEntry approval fields', () {
    test('defaults to pending review', () {
      expect(entry().approvalStatus, ApprovalStatus.pending);
      expect(entry().isPrintable, isFalse);
    });

    test('survives a Firestore round-trip', () {
      final StudentEntry original = entry(approval: ApprovalStatus.rejected)
          .copyWith(
        rejectionReason: 'Photo is blurred',
        reviewedBy: 'admin-uid',
        reviewedAt: DateTime(2026, 9, 4, 10, 30),
      );

      final StudentEntry restored = StudentEntry.fromFirestoreMap(
        original.id,
        original.toFirestoreMap(),
      );

      expect(restored.approvalStatus, ApprovalStatus.rejected);
      expect(restored.rejectionReason, 'Photo is blurred');
      expect(restored.reviewedBy, 'admin-uid');

      // Serialised as UTC, so it comes back as a UTC DateTime rather than the
      // local one that went in. Same instant, different object - compare the
      // instant, which is the property that actually matters.
      expect(
        restored.reviewedAt!.isAtSameMomentAs(original.reviewedAt!),
        isTrue,
        reason: 'the review timestamp must survive the timezone round-trip',
      );
    });

    test('copyWith can explicitly clear a rejection reason', () {
      final StudentEntry rejected =
          entry().copyWith(rejectionReason: 'Bad photo');
      expect(rejected.copyWith(clearRejectionReason: true).rejectionReason, isNull);
      expect(rejected.copyWith().rejectionReason, 'Bad photo');
    });
  });

  group('the print gate', () {
    late IdCardRenderer renderer;
    late ImpositionService service;
    late CardTemplate template;
    late SchoolConfig config;

    setUpAll(() async {
      renderer = await IdCardRenderer.load();
      service = ImpositionService(renderer);
      final String raw =
          await rootBundle.loadString('assets/templates/default_vertical.json');
      template = CardTemplate.fromJson(jsonDecode(raw) as Map<String, Object?>);
      config = const SchoolConfig(id: 's1', name: 'TEST SCHOOL');
    });

    test('unapproved entries never reach a sheet', () async {
      final List<GeneratedPdf> sheets = await service.buildSheets(
        entries: <StudentEntry>[
          entry(id: 'a', approval: ApprovalStatus.pending),
          entry(id: 'b', approval: ApprovalStatus.rejected),
        ],
        config: config,
        template: template,
        cardSize: CardSize.v54x86,
        sheet: SheetSpec.sheet12x18,
      );

      // Nothing approved means nothing to print - and crucially, no sheet full
      // of unreviewed cards.
      expect(sheets, isEmpty);
    });

    test('unapproved entries never reach a single-card export', () async {
      final List<GeneratedPdf> singles = await service.buildSingleCards(
        entries: <StudentEntry>[
          entry(id: 'a', approval: ApprovalStatus.pending),
          entry(id: 'b', approval: ApprovalStatus.rejected),
        ],
        config: config,
        template: template,
        cardSize: CardSize.v54x86,
      );

      expect(singles, isEmpty);
    });

    test('approved entries do print, and mixed batches drop only the rest',
        () async {
      final List<GeneratedPdf> singles = await service.buildSingleCards(
        entries: <StudentEntry>[
          entry(id: 'a', name: 'APPROVED ONE', approval: ApprovalStatus.approved),
          entry(id: 'b', name: 'STILL PENDING'),
          entry(id: 'c', name: 'SENT BACK', approval: ApprovalStatus.rejected),
        ],
        config: config,
        template: template,
        cardSize: CardSize.v54x86,
      );

      expect(singles.length, 1);
      expect(singles.single.fileName, startsWith('APPROVED_ONE'));
    });

    test('the gate holds even if a caller forgets to filter', () async {
      // The point of enforcing it inside the service: the caller here passes
      // everything, and the service still refuses the unapproved rows.
      final List<StudentEntry> unfiltered = <StudentEntry>[
        for (int i = 0; i < 30; i++) entry(id: 'p$i'),
        entry(id: 'ok', approval: ApprovalStatus.approved),
      ];

      final List<GeneratedPdf> sheets = await service.buildSheets(
        entries: unfiltered,
        config: config,
        template: template,
        cardSize: CardSize.v54x86,
        sheet: SheetSpec.sheet12x18,
      );

      // One approved card fits on one sheet, not the 30 unapproved ones.
      expect(sheets.length, 1);
      expect(sheets.single.cardCount, 1);
    });
  });

  group('review persistence', () {
    late AppDatabase db;
    late StudentRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = StudentRepository(db);
    });

    tearDown(() async => db.close());

    test('approve records the decision and re-queues it for upload', () async {
      // Start from a synced row: approving must push it back into the queue,
      // otherwise the decision never leaves the admin's device.
      await repo.save(entry().copyWith(syncStatus: SyncStatus.synced));

      await repo.approve('e1', reviewerUid: 'admin-uid');

      final StudentEntry? found = await repo.findById('e1');
      expect(found!.approvalStatus, ApprovalStatus.approved);
      expect(found.reviewedBy, 'admin-uid');
      expect(found.reviewedAt, isNotNull);
      expect(found.syncStatus, SyncStatus.pending);
      expect(found.rejectionReason, isNull);
    });

    test('reject stores the reason the operator will read', () async {
      await repo.save(entry());

      await repo.reject(
        'e1',
        reviewerUid: 'admin-uid',
        reason: 'Photo is blurred - retake in better light',
      );

      final StudentEntry? found = await repo.findById('e1');
      expect(found!.approvalStatus, ApprovalStatus.rejected);
      expect(found.rejectionReason, contains('blurred'));
      expect(found.syncStatus, SyncStatus.pending);
    });

    test('approving clears a previous rejection reason', () async {
      await repo.save(entry());
      await repo.reject('e1', reviewerUid: 'a', reason: 'Wrong class');
      await repo.approve('e1', reviewerUid: 'a');

      final StudentEntry? found = await repo.findById('e1');
      expect(found!.approvalStatus, ApprovalStatus.approved);
      expect(
        found.rejectionReason,
        isNull,
        reason: 'a stale reason would confuse the operator on an approved card',
      );
    });

    test('bulk approve handles a whole class in one call', () async {
      for (int i = 0; i < 25; i++) {
        await repo.save(entry(id: 'e$i'));
      }

      await repo.approveAll(
        <String>[for (int i = 0; i < 25; i++) 'e$i'],
        reviewerUid: 'admin-uid',
      );

      final List<StudentEntry> printable = await repo.printableForSchool('s1');
      expect(printable.length, 25);
    });

    test('bulk approve with an empty list is a no-op, not an error', () async {
      await repo.approveAll(<String>[], reviewerUid: 'admin-uid');
      expect(await repo.printableForSchool('s1'), isEmpty);
    });

    test('printableForSchool excludes approved entries with no photo', () async {
      await repo.save(entry(id: 'with', approval: ApprovalStatus.approved));
      await repo.save(
        entry(id: 'without', approval: ApprovalStatus.approved, photo: null),
      );

      final List<StudentEntry> printable = await repo.printableForSchool('s1');

      // A card with an empty photo box would waste the whole sheet.
      expect(printable.map((StudentEntry e) => e.id), <String>['with']);
    });

    test('printableForSchool excludes other schools', () async {
      await repo.save(entry(id: 'mine', approval: ApprovalStatus.approved));
      await repo.save(
        entry(id: 'theirs', approval: ApprovalStatus.approved)
            .copyWith(schoolId: 's2'),
      );

      final List<StudentEntry> printable = await repo.printableForSchool('s1');
      expect(printable.map((StudentEntry e) => e.id), <String>['mine']);
    });

    test('entries default to pending review when saved', () async {
      await repo.save(entry());
      final StudentEntry? found = await repo.findById('e1');
      expect(found!.approvalStatus, ApprovalStatus.pending);
      expect(await repo.printableForSchool('s1'), isEmpty);
    });
  });
}
