import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';

/// Resolving a QR code, asking to join, and finding out whether the office
/// has acted.
///
/// Every method here runs as an account that may have no access to anything.
/// That is the normal case, not an error case, so a permission denial is
/// translated into something the teacher can read rather than thrown at them
/// as a Firestore exception.
class JoinRepository {
  JoinRepository(this._db);

  final FirebaseFirestore _db;

  /// Turns a scanned token into the school it invites you to.
  ///
  /// Reads `joinCodes/{token}` by document id. There is no query here on
  /// purpose: a query over `joinCodes` would need list access, which the
  /// rules give only to admins precisely so that one signed-in account
  /// cannot enumerate every school in the installation.
  Future<Object> resolve(String rawScan) async {
    final String token = tokenFrom(rawScan);
    if (token.isEmpty) return ScanFailure.notOurCode;

    try {
      final DocumentSnapshot<Map<String, Object?>> snap = await _db
          .collection('joinCodes')
          .doc(token)
          .get();

      if (!snap.exists) return ScanFailure.unknownCode;

      final SchoolInvitation? invite = SchoolInvitation.fromWire(
        token,
        snap.data(),
      );
      return invite ?? ScanFailure.unknownCode;
    } on FirebaseException catch (e) {
      // A denied read here means the document is gone, not that the account
      // is wrong: the rules let any signed-in user `get` a code. Either way
      // the teacher's next step is the same - ask for the current sheet.
      if (e.code == 'permission-denied') return ScanFailure.unknownCode;
      return ScanFailure.couldNotReach;
    } on Object {
      return ScanFailure.couldNotReach;
    }
  }

  /// Puts this teacher in a school's pending list.
  ///
  /// Writes `status: 'pending'` explicitly rather than relying on a default,
  /// because the rules refuse a request that arrives as anything else. The
  /// client saying "pending" and the server insisting on it are two
  /// independent statements of the same rule, which is the point.
  Future<bool> requestJoin({
    required SchoolInvitation invitation,
    required String uid,
    required String displayName,
    required String email,
  }) async {
    try {
      await _db
          .collection('schools')
          .doc(invitation.schoolId)
          .collection('joinRequests')
          .doc(uid)
          .set(<String, Object?>{
            'uid': uid,
            'schoolId': invitation.schoolId,
            'displayName': displayName,
            'email': email,
            'status': 'pending',
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
          });
      return true;
    } on Object {
      return false;
    }
  }

  /// Where this teacher stands, right now.
  ///
  /// Reads the user document, which is the only thing a pending teacher is
  /// allowed to read about themselves. The answer comes from `schoolId` and
  /// `assignment` - both admin-written - and never from the join request,
  /// which is bookkeeping for the office and carries no authority.
  Future<JoinState> currentState(String uid) async {
    try {
      final DocumentSnapshot<Map<String, Object?>> snap = await _db
          .collection('users')
          .doc(uid)
          .get();

      final Map<String, Object?>? data = snap.data();
      if (data == null) return JoinState.none;

      final Object? assignment = data['assignment'];
      final String schoolId = _string(data['schoolId']);

      if (assignment is Map<String, Object?>) {
        return JoinState(
          status: JoinStatus.fromWire(_string(assignment['status'])),
          schoolId: schoolId.isNotEmpty
              ? schoolId
              : _string(assignment['schoolId']),
          classLevel: _string(assignment['classLevel']),
          division: _string(assignment['division']),
        );
      }

      // A school but no assignment is every account that predates sections.
      // Treated as active and unscoped, matching the rules, which narrow
      // nobody who has not been given a section.
      if (schoolId.isNotEmpty) {
        return JoinState(status: JoinStatus.active, schoolId: schoolId);
      }

      return JoinState.none;
    } on Object {
      return JoinState.none;
    }
  }

  /// Watches for the office acting, so screen 18 updates without a tap.
  ///
  /// "Check again" is still on that screen. A teacher who has been waiting
  /// wants to do something, and a button that returns the same answer is
  /// kinder than a screen that looks frozen.
  Stream<JoinState> watchState(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((DocumentSnapshot<Map<String, Object?>> snap) {
        final Map<String, Object?>? data = snap.data();
        if (data == null) return JoinState.none;
        final Object? assignment = data['assignment'];
        final String schoolId = _string(data['schoolId']);
        if (assignment is Map<String, Object?>) {
          return JoinState(
            status: JoinStatus.fromWire(_string(assignment['status'])),
            schoolId: schoolId.isNotEmpty
                ? schoolId
                : _string(assignment['schoolId']),
            classLevel: _string(assignment['classLevel']),
            division: _string(assignment['division']),
          );
        }
        if (schoolId.isNotEmpty) {
          return JoinState(status: JoinStatus.active, schoolId: schoolId);
        }
        return JoinState.none;
      })
      .handleError((Object _) => JoinState.none);

  /// Whether this teacher already has a request waiting at a school.
  Future<bool> hasPendingRequest({
    required String schoolId,
    required String uid,
  }) async {
    try {
      final DocumentSnapshot<Map<String, Object?>> snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('joinRequests')
          .doc(uid)
          .get();
      return snap.exists;
    } on Object {
      return false;
    }
  }

  /// Pulls a token out of whatever the camera read.
  ///
  /// Public because it is the part of this class worth testing on its own:
  /// it is pure, and it is where a scanned Wi-Fi card or a rotated URL
  /// format turns into either a token or a polite refusal.
  ///
  /// Accepts the bare token and a URL carrying it, because a printed sheet
  /// is a physical object that outlives the decision about what to encode -
  /// and a code that stops working after a format change is a code somebody
  /// has to reprint and re-pin in every staffroom.
  static String tokenFrom(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final Uri? uri = Uri.tryParse(trimmed);
    // Only http(s). A Wi-Fi join card scans as `WIFI:S:StaffRoom;T:WPA;...`,
    // which Dart parses quite happily as a URI with scheme `wifi` - and
    // whose last path segment was being handed to Firestore as a document
    // id. Restricting the scheme is what stops every other QR standard from
    // looking like one of ours.
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final String? param =
          uri.queryParameters['code'] ?? uri.queryParameters['token'];
      if (param != null && _isToken(param)) return param;
      if (uri.pathSegments.isNotEmpty) {
        final String last = uri.pathSegments.last;
        if (_isToken(last)) return last;
      }
      return '';
    }

    return _isToken(trimmed) ? trimmed : '';
  }

  /// Whether a string could be one of our tokens at all.
  ///
  /// Matches the alphabet the panel generates from, plus `-` and `_` so a
  /// future format is not locked out. Anything with punctuation in it -
  /// vCards, Wi-Fi cards, URLs we did not recognise - fails here rather than
  /// becoming a Firestore document id, which throws instead of failing
  /// politely.
  static bool _isToken(String v) =>
      v.length >= 4 &&
      v.length <= 64 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v);

  static String _string(Object? v) => v is String ? v : '';
}
