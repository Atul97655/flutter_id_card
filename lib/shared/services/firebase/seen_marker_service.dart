import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_id_card/features/auth/data/auth_repository.dart'
    show kUsersCollection;
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_id_card/shared/services/local/app_flag_repository.dart';

/// Keeps "I have already seen this" on the account instead of on the handset.
///
/// The device alone could not hold it. Everything the badge is counted
/// against lives in Drift, and Drift lives in the app's private storage,
/// which Android deletes on uninstall. So a reinstall - the first thing
/// anybody does when an app misbehaves - handed back a phone announcing every
/// approval and every returned card as fresh news, including ones that had
/// been read weeks earlier. The app looked like it had forgotten, because it
/// had.
///
/// Mirroring to `users/{uid}` fixes that, and fixes the second handset at the
/// same time: a head teacher who reads a notification on the office phone
/// does not get shouted at about it again on their own.
///
/// ## Why the merge is a union
///
/// Seen is monotonic per id: having looked at something is not undone by
/// another device not having looked at it. A union can only ever hide a row
/// that someone has genuinely read on some device, whereas an
/// last-write-wins merge would resurrect rows at random depending on which
/// device synced last. The set is re-grounded to what is actually on screen
/// every time the notifications screen is opened, so the union cannot grow
/// without bound - see [AppFlagRepository.markNotificationsSeen].
class SeenMarkerService {
  SeenMarkerService({
    required this.flags,
    FirebaseFirestore? firestore,
    bool Function()? isFirebaseReady,
  }) : _firestoreOverride = firestore,
       _isFirebaseReady =
           isFirebaseReady ?? (() => FirebaseBootstrap.instance.isReady);

  final AppFlagRepository flags;
  final FirebaseFirestore? _firestoreOverride;
  final bool Function() _isFirebaseReady;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  /// The two field names on `users/{uid}`, matching the local flag keys so
  /// there is only one vocabulary to remember.
  static const String notificationsField = 'notificationsSeenIds';
  static const String returnedField = 'returnedDismissedIds';

  /// How many ids are kept when merging a remote set in.
  ///
  /// A ceiling exists only to stop a pathological account - years of cards,
  /// never once opening the notifications screen, which would otherwise
  /// re-ground the set - from writing an ever-growing array into a document
  /// with a 1MB limit. Ordinary use never approaches it.
  static const int _ceiling = 400;

  /// Brings the account's seen sets down onto this device.
  ///
  /// Called once per signed-in session, before the first frame that could
  /// show a badge. A failure here is silent and leaves the local sets alone:
  /// the cost of a missed pull is a badge that says more than it should,
  /// which is recoverable by opening the screen. The cost of throwing would
  /// be a sign-in that fails because a cosmetic counter could not be read.
  Future<void> pullFor(String uid) async {
    if (uid.isEmpty || !_isFirebaseReady()) return;
    try {
      final DocumentSnapshot<Map<String, Object?>> snap = await _db
          .collection(kUsersCollection)
          .doc(uid)
          .get();
      final Map<String, Object?>? data = snap.data();
      if (data == null) return;

      await _reconcile(
        uid: uid,
        field: notificationsField,
        key: AppFlagRepository.notificationsSeenIdsKey,
        data: data,
      );
      await _reconcile(
        uid: uid,
        field: returnedField,
        key: AppFlagRepository.returnedDismissedIdsKey,
        data: data,
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Seen-marker pull failed: $e');
    }
  }

  /// Makes the device and the account agree, in whichever direction is short.
  ///
  /// It pushes as well as pulls, which matters more than it looks. Opening
  /// the notifications screen in a school with no signal writes the set
  /// locally and loses the upload; if nothing ever sent it afterwards, the
  /// account would still not know, and the next reinstall would re-announce
  /// everything - the exact failure this class exists to prevent, arrived at
  /// by a different road. Reconciling on every sign-in closes that door.
  Future<void> _reconcile({
    required String uid,
    required String field,
    required String key,
    required Map<String, Object?> data,
  }) async {
    final Object? raw = data[field];
    final Set<String> remote = raw is List<Object?>
        ? raw.whereType<String>().toSet()
        : <String>{};

    final Set<String> local = await flags.readStringSet(key);
    if (local.isEmpty && remote.isEmpty) return;

    Set<String> merged = <String>{...local, ...remote};
    if (merged.length > _ceiling) {
      merged = merged.toList().sublist(merged.length - _ceiling).toSet();
    }

    if (merged.length != local.length) await flags.writeStringSet(key, merged);
    if (merged.length != remote.length) {
      await _push(uid: uid, field: field, ids: merged);
    }
  }

  /// Records the notifications that were on screen as seen, here and on the
  /// account.
  ///
  /// The local write is awaited and the remote one is not: the badge must
  /// clear the instant the operator looks, on a connection that may well be
  /// dead, and a notification counter is not worth blocking a screen on.
  Future<void> markNotificationsSeen({
    required String uid,
    required Set<String> visibleIds,
  }) async {
    await flags.markNotificationsSeen(visibleIds);
    await _push(uid: uid, field: notificationsField, ids: visibleIds);
  }

  /// Records that the operator has dismissed the returned-cards banner for
  /// these entries.
  Future<void> dismissReturnedCards({
    required String uid,
    required Set<String> entryIds,
  }) async {
    final Set<String> merged = await flags.addToStringSet(
      AppFlagRepository.returnedDismissedIdsKey,
      entryIds,
    );
    await _push(uid: uid, field: returnedField, ids: merged);
  }

  Future<void> _push({
    required String uid,
    required String field,
    required Set<String> ids,
  }) async {
    if (uid.isEmpty || !_isFirebaseReady()) return;
    try {
      final List<String> sorted = ids.toList()..sort();
      await _db.collection(kUsersCollection).doc(uid).set(<String, Object?>{
        field: sorted,
      }, SetOptions(merge: true));
    } on Object catch (e) {
      // Offline, or an account whose profile document an admin has not
      // created yet. The local write already happened, so the operator sees
      // the badge clear; the account simply learns about it on the next
      // device that manages to write.
      if (kDebugMode) debugPrint('Seen-marker push failed: $e');
    }
  }
}
