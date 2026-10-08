import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_id_card/shared/services/firebase/seen_marker_service.dart';
import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/app_flag_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// "I have already seen this" has to outlive the installation.
///
/// The complaint behind all of this: open the notifications, read them, and
/// they are back on the next launch - and after reinstalling the app, back
/// again from the beginning, announcing approvals from weeks earlier. The
/// first half was a clock problem and is pinned in
/// poa_phase3_shell_profile_test.dart. This file is the second half: the
/// record lived in the app's private storage, which Android deletes with the
/// app, so a reinstall genuinely wiped it.
void main() {
  late AppDatabase db;
  late AppFlagRepository flags;
  late FakeFirebaseFirestore firestore;
  late SeenMarkerService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    flags = AppFlagRepository(db);
    firestore = FakeFirebaseFirestore();
    service = SeenMarkerService(
      flags: flags,
      firestore: firestore,
      isFirebaseReady: () => true,
    );
  });

  tearDown(() async => db.close());

  group('Marking seen', () {
    test('records on the device AND on the account', () async {
      await service.markNotificationsSeen(
        uid: 'u1',
        visibleIds: <String>{'entry-1-approved-100', 'chat-c1-200'},
      );

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'entry-1-approved-100', 'chat-c1-200'},
      );

      final Map<String, Object?>? remote = (await firestore
              .collection('users')
              .doc('u1')
              .get())
          .data();
      expect(remote?[SeenMarkerService.notificationsField], <String>[
        'chat-c1-200',
        'entry-1-approved-100',
      ]);
    });

    test('merges into the profile rather than replacing it', () async {
      // The user document holds the role and the school assignment. A write
      // that dropped those would lock the operator out of every rule in the
      // project, which is a far worse outcome than a stuck badge.
      await firestore.collection('users').doc('u1').set(<String, Object?>{
        'role': 'Teacher',
        'schoolId': 'school-1',
      });

      await service.markNotificationsSeen(
        uid: 'u1',
        visibleIds: <String>{'a'},
      );

      final Map<String, Object?>? remote = (await firestore
              .collection('users')
              .doc('u1')
              .get())
          .data();
      expect(remote?['role'], 'Teacher');
      expect(remote?['schoolId'], 'school-1');
      expect(remote?[SeenMarkerService.notificationsField], <String>['a']);
    });

    test('a dead connection still clears the badge on the device', () async {
      // Local first, remote best-effort. An operator in a school with no
      // signal must still be able to make the bell stop.
      final SeenMarkerService offline = SeenMarkerService(
        flags: flags,
        firestore: firestore,
        isFirebaseReady: () => false,
      );

      await offline.markNotificationsSeen(uid: 'u1', visibleIds: <String>{'a'});

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'a'},
      );
      expect(
        (await firestore.collection('users').doc('u1').get()).exists,
        isFalse,
        reason: 'nothing should have been attempted against the network',
      );
    });
  });

  group('A reinstall', () {
    test('gets its seen set back from the account', () async {
      // The whole point. `flags` here is a brand new database, exactly as it
      // is on a device that has just reinstalled the app.
      await firestore.collection('users').doc('u1').set(<String, Object?>{
        SeenMarkerService.notificationsField: <String>[
          'entry-1-approved-100',
          'entry-2-rejected-200',
        ],
        SeenMarkerService.returnedField: <String>['entry-9'],
      });

      await service.pullFor('u1');

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'entry-1-approved-100', 'entry-2-rejected-200'},
      );
      expect(
        await flags.readStringSet(AppFlagRepository.returnedDismissedIdsKey),
        <String>{'entry-9'},
      );
    });

    test('keeps anything this device had seen that the account had not',
        () async {
      // Two handsets. Having read something on one of them is a fact; not
      // having read it on the other is not evidence against it. A union can
      // only ever hide a row somebody genuinely read.
      await flags.writeStringSet(AppFlagRepository.notificationsSeenIdsKey, <String>{
        'local-only',
      });
      await firestore.collection('users').doc('u1').set(<String, Object?>{
        SeenMarkerService.notificationsField: <String>['remote-only'],
      });

      await service.pullFor('u1');

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'local-only', 'remote-only'},
      );
    });

    test('an upload lost to a dead connection is sent on the next sign-in',
        () async {
      // Reading the notifications in a school with no signal writes the set
      // locally and loses the upload. If nothing ever sent it afterwards, the
      // next reinstall would re-announce everything - the same failure by a
      // different road.
      await flags.writeStringSet(
        AppFlagRepository.notificationsSeenIdsKey,
        <String>{'read-while-offline'},
      );
      await firestore.collection('users').doc('u1').set(<String, Object?>{
        'role': 'Teacher',
      });

      await service.pullFor('u1');

      final Map<String, Object?>? remote = (await firestore
              .collection('users')
              .doc('u1')
              .get())
          .data();
      expect(remote?[SeenMarkerService.notificationsField], <String>[
        'read-while-offline',
      ]);
    });

    test('a missing profile document leaves the device alone', () async {
      await flags.writeStringSet(
        AppFlagRepository.notificationsSeenIdsKey,
        <String>{'a'},
      );

      await service.pullFor('no-such-user');

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        <String>{'a'},
      );
    });

    test('junk in the remote field is ignored, not crashed on', () async {
      // This runs before the first frame of a signed-in session. Whatever is
      // in that document, the app has to start.
      await firestore.collection('users').doc('u1').set(<String, Object?>{
        SeenMarkerService.notificationsField: 'not a list',
      });

      await service.pullFor('u1');

      expect(
        await flags.readStringSet(AppFlagRepository.notificationsSeenIdsKey),
        isEmpty,
      );
    });
  });

  group('Dismissing a returned card', () {
    test('accumulates instead of replacing', () async {
      // Waving away today's returned card must not un-dismiss yesterday's,
      // or the banner comes back for a card already dealt with - which is the
      // behaviour being fixed.
      await service.dismissReturnedCards(
        uid: 'u1',
        entryIds: <String>{'card-1'},
      );
      await service.dismissReturnedCards(
        uid: 'u1',
        entryIds: <String>{'card-2'},
      );

      expect(
        await flags.readStringSet(AppFlagRepository.returnedDismissedIdsKey),
        <String>{'card-1', 'card-2'},
      );

      final Map<String, Object?>? remote = (await firestore
              .collection('users')
              .doc('u1')
              .get())
          .data();
      expect(remote?[SeenMarkerService.returnedField], <String>[
        'card-1',
        'card-2',
      ]);
    });
  });
}
