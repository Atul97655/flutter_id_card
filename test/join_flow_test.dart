/// Joining a school: resolving a code, asking, and waiting.
///
/// The security of this flow is in the Firestore rules, which are tested
/// against the emulator. What is tested here is the half the rules cannot
/// cover: whether a teacher holding a poster that no longer works is told
/// something they can act on, and whether the app ever decides on its own
/// that somebody is approved.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_id_card/features/onboarding/data/join_repository.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late JoinRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = JoinRepository(db);
  });

  Future<void> seedCode(String token, {String school = 'SJS-2026-0041'}) =>
      db.collection('joinCodes').doc(token).set(<String, Object?>{
        'schoolId': school,
        'schoolName': 'ST. JOHN SAMARITAN SCHOOL',
      });

  group('reading a scanned code', () {
    test('a bare token is the token', () {
      expect(JoinRepository.tokenFrom('Kx7Rm2Qp'), 'Kx7Rm2Qp');
      expect(JoinRepository.tokenFrom('  Kx7Rm2Qp  '), 'Kx7Rm2Qp');
    });

    // A printed sheet outlives the decision about what to encode on it, so
    // both shapes have to keep working or somebody re-pins every staffroom.
    test('a URL carrying the token still resolves', () {
      expect(
        JoinRepository.tokenFrom('https://id-entity.app/join?code=Kx7Rm2Qp'),
        'Kx7Rm2Qp',
      );
      expect(
        JoinRepository.tokenFrom('https://id-entity.app/join?token=Kx7Rm2Qp'),
        'Kx7Rm2Qp',
      );
      expect(
        JoinRepository.tokenFrom('https://id-entity.app/join/Kx7Rm2Qp'),
        'Kx7Rm2Qp',
      );
    });

    test('something that is plainly not a code is refused', () {
      expect(JoinRepository.tokenFrom(''), '');
      expect(JoinRepository.tokenFrom('   '), '');
      expect(
        JoinRepository.tokenFrom('WIFI:S:StaffRoom;T:WPA;P:hunter2;;'),
        '',
        reason:
            'a scanned Wi-Fi card must not be sent to Firestore as a '
            'document id, which throws rather than failing politely',
      );
      expect(JoinRepository.tokenFrom('a' * 200), '');
    });

    test('a non-code scan reports the right failure', () async {
      expect(
        await repo.resolve('BEGIN:VCARD more stuff'),
        ScanFailure.notOurCode,
      );
    });
  });

  group('resolving against the office', () {
    test('a live code names its school', () async {
      await seedCode('Kx7Rm2Qp');

      final Object result = await repo.resolve('Kx7Rm2Qp');

      expect(result, isA<SchoolInvitation>());
      final SchoolInvitation invite = result as SchoolInvitation;
      expect(invite.schoolId, 'SJS-2026-0041');
      expect(invite.schoolName, 'ST. JOHN SAMARITAN SCHOOL');
    });

    // The scenario the wording exists for: a poster that worked last week.
    test(
      'a rotated code says it was replaced, not that it is invalid',
      () async {
        final Object result = await repo.resolve('OldCode99');

        expect(result, ScanFailure.unknownCode);
        expect((result as ScanFailure).message, contains('no longer in use'));
        expect(result.message, contains('new one'));
        expect(
          result.message.toLowerCase(),
          isNot(contains('invalid')),
          reason:
              'a teacher told their code is invalid goes to the office to '
              'report a broken app, not to collect the current sheet',
        );
      },
    );

    test('a malformed code document is treated as unknown', () async {
      await db.collection('joinCodes').doc('Broken').set(<String, Object?>{
        'schoolName': 'NO SCHOOL ID HERE',
      });

      expect(await repo.resolve('Broken'), ScanFailure.unknownCode);
    });
  });

  group('asking to join', () {
    test('writes a pending request under the teacher own uid', () async {
      await seedCode('Kx7Rm2Qp');
      final SchoolInvitation invite =
          await repo.resolve('Kx7Rm2Qp') as SchoolInvitation;

      final bool ok = await repo.requestJoin(
        invitation: invite,
        uid: 'uid-ramesh',
        displayName: 'RAMESH PATIL',
        email: 'ramesh@stjohn.edu',
      );

      expect(ok, isTrue);
      final Map<String, Object?>? doc =
          (await db
                  .collection('schools')
                  .doc('SJS-2026-0041')
                  .collection('joinRequests')
                  .doc('uid-ramesh')
                  .get())
              .data();

      expect(doc, isNotNull);
      expect(doc!['uid'], 'uid-ramesh');
      expect(
        doc['status'],
        'pending',
        reason:
            'the client states the rule the server also enforces; both '
            'saying it is the point',
      );
    });

    test('knows when a request is already waiting', () async {
      await seedCode('Kx7Rm2Qp');
      final SchoolInvitation invite =
          await repo.resolve('Kx7Rm2Qp') as SchoolInvitation;

      expect(
        await repo.hasPendingRequest(
          schoolId: invite.schoolId,
          uid: 'uid-ramesh',
        ),
        isFalse,
      );

      await repo.requestJoin(
        invitation: invite,
        uid: 'uid-ramesh',
        displayName: 'RAMESH PATIL',
        email: 'ramesh@stjohn.edu',
      );

      expect(
        await repo.hasPendingRequest(
          schoolId: invite.schoolId,
          uid: 'uid-ramesh',
        ),
        isTrue,
      );
    });
  });

  group('where a teacher stands', () {
    Future<void> user(Map<String, Object?> data) =>
        db.collection('users').doc('uid-ramesh').set(data);

    test('a fresh account is not in any school', () async {
      await user(<String, Object?>{'role': 'Teacher', 'active': true});

      final JoinState state = await repo.currentState('uid-ramesh');

      expect(state.isReady, isFalse);
      expect(state.schoolId, isEmpty);
    });

    // The assertion that keeps the pending state honest: only the office
    // writing an assignment moves anyone forward.
    test('a pending assignment is not ready', () async {
      await user(<String, Object?>{
        'role': 'Teacher',
        'active': true,
        'assignment': <String, Object?>{
          'schoolId': 'SJS-2026-0041',
          'classLevel': '10',
          'division': 'A',
          'status': 'pending',
        },
      });

      final JoinState state = await repo.currentState('uid-ramesh');

      expect(state.status, JoinStatus.pending);
      expect(state.isReady, isFalse);
    });

    test('an active assignment with a section is ready', () async {
      await user(<String, Object?>{
        'role': 'Teacher',
        'active': true,
        'schoolId': 'SJS-2026-0041',
        'assignment': <String, Object?>{
          'schoolId': 'SJS-2026-0041',
          'classLevel': '10',
          'division': 'A',
          'status': 'active',
        },
      });

      final JoinState state = await repo.currentState('uid-ramesh');

      expect(state.isReady, isTrue);
      expect(state.sectionLabel, '10 - A');
    });

    test('a half-written assignment is not ready', () async {
      await user(<String, Object?>{
        'role': 'Teacher',
        'active': true,
        'schoolId': 'SJS-2026-0041',
        'assignment': <String, Object?>{
          'schoolId': 'SJS-2026-0041',
          'classLevel': '10',
          'division': '',
          'status': 'active',
        },
      });

      expect(
        (await repo.currentState('uid-ramesh')).isReady,
        isFalse,
        reason:
            'letting someone through on half an assignment puts them in '
            'a school with no section, which the rules read as the whole '
            'school',
      );
    });

    // Grandfathering. Every account that existed before sections is this.
    test('a school with no assignment is active and unscoped', () async {
      await user(<String, Object?>{
        'role': 'Teacher',
        'active': true,
        'schoolId': 'SJS-2026-0041',
      });

      final JoinState state = await repo.currentState('uid-ramesh');

      expect(state.status, JoinStatus.active);
      expect(state.schoolId, 'SJS-2026-0041');
      expect(state.sectionLabel, isEmpty);
      expect(
        state.isReady,
        isFalse,
        reason:
            'isReady means "scoped to a section"; an unscoped teacher '
            'still works, they just have no chip to show',
      );
    });

    test('an unknown status never reads as approved', () async {
      await user(<String, Object?>{
        'role': 'Teacher',
        'active': true,
        'schoolId': 'SJS-2026-0041',
        'assignment': <String, Object?>{
          'schoolId': 'SJS-2026-0041',
          'classLevel': '10',
          'division': 'A',
          'status': 'super-approved',
        },
      });

      final JoinState state = await repo.currentState('uid-ramesh');

      expect(state.status, JoinStatus.pending);
      expect(state.isReady, isFalse);
    });

    test('the office approving arrives on the stream', () async {
      await user(<String, Object?>{'role': 'Teacher', 'active': true});

      final Future<JoinState> ready = repo
          .watchState('uid-ramesh')
          .firstWhere((JoinState s) => s.isReady);

      await db.collection('users').doc('uid-ramesh').set(<String, Object?>{
        'role': 'Teacher',
        'active': true,
        'schoolId': 'SJS-2026-0041',
        'assignment': <String, Object?>{
          'schoolId': 'SJS-2026-0041',
          'classLevel': '10',
          'division': 'A',
          'status': 'active',
        },
      });

      expect((await ready).sectionLabel, '10 - A');
    });
  });

  group('the words a teacher reads', () {
    test('every failure says what to do next', () {
      for (final ScanFailure f in ScanFailure.values) {
        expect(f.message, isNotEmpty, reason: f.name);
        expect(
          f.message.length,
          greaterThan(30),
          reason: '${f.name} is too terse to be actionable',
        );
      }
    });
  });
}
