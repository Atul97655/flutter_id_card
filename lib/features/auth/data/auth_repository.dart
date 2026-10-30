import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Domain part of the synthetic email addresses used for school logins.
///
/// Firebase Auth only authenticates email/password pairs, but the spec calls
/// for operators to sign in with a *school name*. We bridge that by deriving a
/// deterministic address from the school code: `stjohns` -> the address below.
/// The admin panel creates the Auth user with exactly this address when a
/// school is added, so the two always agree and no unauthenticated Firestore
/// read is needed to resolve a school name to an email.
///
/// Change this to the organisation's own domain before rollout.
const String kSchoolAuthDomain = 'schools.idcardx.app';

/// Firestore collection holding role assignments, keyed by Auth UID.
const String kUsersCollection = 'users';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  static const String _sessionCacheKey = 'cached_session_user';
  static const String _knownSchoolsKey = 'known_school_codes';

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  bool get isBackendAvailable => FirebaseBootstrap.instance.isReady;

  /// Turns a typed school code into the address Firebase Auth expects.
  /// An input that already looks like an email is passed through untouched, so
  /// the organisation can migrate to real addresses without a code change.
  static String schoolCodeToEmail(String schoolCode) {
    final String cleaned = schoolCode.trim().toLowerCase();
    if (cleaned.contains('@')) return cleaned;
    // Auth rejects addresses with spaces or most punctuation.
    final String slug = cleaned.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$slug@$kSchoolAuthDomain';
  }

  // ------------------------------------------------------------------
  // Self-registration
  // ------------------------------------------------------------------

  /// Creates a teacher account that has access to nothing.
  ///
  /// This is what makes the QR join flow possible. The panel cannot mint an
  /// account - creating a Firebase Auth user from the browser SDK signs the
  /// admin out of their own session, and doing it properly needs the Admin
  /// SDK on a server this project does not have. So the teacher signs
  /// themselves up and then scans their school's code.
  ///
  /// The profile written here deliberately carries no `schoolId` and no
  /// `assignment`. Those two fields are what every read rule in this project
  /// reaches a school through, only an admin may write them, and the rules
  /// refuse a self-created document that contains either. An account made by
  /// this method is an identity and nothing more until somebody in the office
  /// approves the join.
  ///
  /// `role` is pinned to Teacher for the same reason. Without it the first
  /// thing a stranger would write onto their own document is `Admin`.
  ///
  /// [role] is [UserRole.teacher] or [UserRole.parent]. The rules accept only
  /// those two on a self-created profile, so passing anything else here would
  /// fail at the write, not grant anything.
  Future<SessionUser> registerTeacher({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.teacher,
  }) async {
    if (!isBackendAvailable) {
      throw const AuthFailure(
        'Cannot reach the server. Check that Firebase is configured '
        '(google-services.json) and that you have a connection.',
      );
    }

    final String cleanEmail = email.trim().toLowerCase();
    final String name = displayName.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const AuthFailure(
        'Enter the email address you want to sign in with',
      );
    }
    if (name.isEmpty) {
      throw const AuthFailure(
        'Enter your name, so the office knows who you are',
      );
    }
    if (password.length < 6) {
      throw const AuthFailure('Choose a password of at least 6 characters');
    }

    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describeRegistrationError(e));
    }

    final User? fbUser = credential.user;
    if (fbUser == null) {
      throw const AuthFailure('Could not create the account. Try again.');
    }

    try {
      await _db.collection('users').doc(fbUser.uid).set(<String, Object?>{
        'email': cleanEmail,
        'role': role.wireValue,
        'displayName': name,
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } on Object {
      // An Auth user with no profile document can never sign in - every rule
      // needs `users/{uid}` to exist - and the address would be taken, so a
      // retry would fail as "already in use" with no way forward. Undoing the
      // Auth half leaves the teacher able to simply try again.
      await fbUser.delete().catchError((Object _) {});
      throw const AuthFailure(
        'Could not finish setting up the account. Check your connection and '
        'try again.',
      );
    }

    final SessionUser session = SessionUser(
      uid: fbUser.uid,
      email: cleanEmail,
      role: role,
      displayName: name,
    );
    await _cacheSession(session);
    return session;
  }

  static String _describeRegistrationError(FirebaseAuthException e) =>
      switch (e.code) {
        'email-already-in-use' =>
          'That email already has an account. Sign in with it instead.',
        'invalid-email' => 'That does not look like an email address.',
        'weak-password' => 'Choose a longer password - at least 6 characters.',
        'operation-not-allowed' =>
          'Sign-ups are switched off for this project. Ask the office to '
              'create your account.',
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        _ => 'Could not create the account (${e.code}).',
      };

  // ------------------------------------------------------------------
  // Sign in
  // ------------------------------------------------------------------

  Future<SessionUser> signInAsSchool({
    required String schoolCode,
    required String password,
  }) async {
    if (schoolCode.trim().isEmpty) {
      throw const AuthFailure('Enter your school name or code');
    }
    final SessionUser user = await _signIn(
      email: schoolCodeToEmail(schoolCode),
      password: password,
      expectedRole: UserRole.school,
    );
    await _rememberSchoolCode(schoolCode.trim());
    return user;
  }

  Future<SessionUser> _signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    if (!isBackendAvailable) {
      throw const AuthFailure(
        'Cannot reach the server. Check that Firebase is configured '
        '(google-services.json) and that you have a connection.',
      );
    }
    if (password.isEmpty) {
      throw const AuthFailure('Enter your password');
    }

    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describeAuthError(e, expectedRole));
    }

    final User? fbUser = credential.user;
    if (fbUser == null) {
      throw const AuthFailure('Sign-in failed. Try again.');
    }

    final SessionUser session = await _loadProfile(fbUser);

    // An admin is turned away here, with their reason, rather than let in to
    // a version of the app that no longer has anything for them.
    //
    // The whole office side - schools, the review queue, exports, reports,
    // announcements - is the web panel's now, and none of those screens
    // exist in this build. Signing an admin in would put them on a home
    // screen with no school and an empty card list, which reads as an app
    // that has lost their data rather than one they are on the wrong device
    // for. Signing out again matters as much as the message: a cached admin
    // session would otherwise come back on every launch.
    if (session.role == UserRole.admin) {
      await _auth.signOut();
      await _clearCachedSession();
      throw const AuthFailure(
        'This is an admin account. The office is managed from the web panel '
        '- open it in a browser instead.',
      );
    }

    // Compared by privilege class, not exact role. Sign-in accepts both
    // School and Teacher accounts - they are the same data scope, and an
    // exact-equality check here would lock every Teacher account out.
    if (!session.role.isOperator) {
      await _auth.signOut();
      throw const AuthFailure('This account cannot sign in here.');
    }
    if (!session.canEnterData) {
      await _auth.signOut();
      throw const AuthFailure(
        'This account has no school assigned. Ask your administrator to set '
        'schoolId on the user record.',
      );
    }

    await _cacheSession(session);
    unawaited_(_touchLastLogin(session.uid));
    return session;
  }

  /// Reads the role document. Primary lookup is by UID, which is what the
  /// security rules key off. The email fallback exists because Firestore
  /// documents created by hand in the console get an auto-ID instead of the
  /// UID - it keeps those working while the data is migrated.
  Future<SessionUser> _loadProfile(User fbUser) async {
    final String email = fbUser.email ?? '';

    Map<String, Object?>? data;
    try {
      final DocumentSnapshot<Map<String, Object?>> byUid = await _db
          .collection(kUsersCollection)
          .doc(fbUser.uid)
          .get();
      if (byUid.exists) {
        data = byUid.data();
      } else if (email.isNotEmpty) {
        final QuerySnapshot<Map<String, Object?>> byEmail = await _db
            .collection(kUsersCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          data = byEmail.docs.first.data();
        }
      }
    } on FirebaseException catch (e) {
      throw AuthFailure('Could not read your account profile: ${e.message}');
    }

    if (data == null) {
      await _auth.signOut();
      throw const AuthFailure(
        'No profile found for this account. Ask your administrator to create '
        'a users record with a role.',
      );
    }

    if (data['active'] == false) {
      await _auth.signOut();
      throw const AuthFailure('This account has been deactivated.');
    }

    return SessionUser(
      uid: fbUser.uid,
      email: email,
      role: UserRole.fromWire(data['role'] as String?),
      schoolId: data['schoolId'] as String?,
      displayName: (data['displayName'] as String?) ?? '',
    );
  }

  /// Best-effort: a failure here must never block a login.
  Future<void> _touchLastLogin(String uid) async {
    try {
      await _db.collection(kUsersCollection).doc(uid).set(<String, Object?>{
        'lastLoginDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on Object {
      // Intentionally ignored - see doc comment.
    }
  }

  // ------------------------------------------------------------------
  // Session restore & sign out
  // ------------------------------------------------------------------

  /// Restores a session on app start.
  ///
  /// Firebase Auth persists credentials on device, so `currentUser` is
  /// populated even with no network. We prefer the locally cached profile in
  /// that case rather than blocking the splash screen on a Firestore read that
  /// may never complete.
  Future<SessionUser?> restoreSession() async {
    if (!isBackendAvailable) return null;

    final User? fbUser = _auth.currentUser;
    if (fbUser == null) return null;

    final SessionUser? cached = await _readCachedSession();

    // An admin signed in on an older build still has a valid Firebase
    // credential and a cached profile on this device. Restoring it would walk
    // straight past the refusal in `_signIn`, because that only runs when
    // somebody types a password. This is where an upgrade actually lands.
    if (cached != null && cached.role == UserRole.admin) {
      await signOut();
      return null;
    }

    if (cached != null && cached.uid == fbUser.uid) {
      // Refresh in the background so a role change lands on the next frame
      // without making the operator wait for it now.
      unawaited_(_refreshCachedProfile(fbUser));
      return cached;
    }

    try {
      final SessionUser fresh = await _loadProfile(fbUser);
      if (fresh.role == UserRole.admin) {
        await signOut();
        return null;
      }
      await _cacheSession(fresh);
      return fresh;
    } on AuthFailure {
      return null;
    }
  }

  Future<void> _refreshCachedProfile(User fbUser) async {
    try {
      await _cacheSession(await _loadProfile(fbUser));
    } on Object {
      // Offline or transient - the cached session stays valid.
    }
  }

  Future<void> signOut() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionCacheKey);
    if (isBackendAvailable) {
      await _auth.signOut();
    }
  }

  /// Changes the signed-in account's password.
  ///
  /// Re-authenticates with [currentPassword] first. Firebase requires a recent
  /// login for a password change and otherwise fails with
  /// `requires-recent-login` after the operator has already typed a new
  /// password twice - re-authenticating up front turns that into a clear
  /// "current password is wrong" instead.
  ///
  /// A reset-by-email flow deliberately is not offered: school accounts use a
  /// synthetic address (`<code>@$kSchoolAuthDomain`) that never receives mail,
  /// so a reset link would silently go nowhere.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isBackendAvailable) {
      throw const AuthFailure(
        'Cannot reach the server. Connect to the internet and try again.',
      );
    }

    final User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthFailure('You are not signed in.');
    }
    if (newPassword.length < 6) {
      throw const AuthFailure(
        'The new password must be at least 6 characters.',
      );
    }
    if (newPassword == currentPassword) {
      throw const AuthFailure('The new password is the same as the old one.');
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(switch (e.code) {
        'wrong-password' ||
        'invalid-credential' => 'That is not your current password.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' =>
          'No connection. Try again when you are online.',
        _ => 'Could not verify your current password (${e.code}).',
      });
    }

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(switch (e.code) {
        'weak-password' => 'That password is too easy to guess.',
        'requires-recent-login' =>
          'Sign out and sign in again, then change the password.',
        _ => 'Could not change the password (${e.code}).',
      });
    }
  }

  // ------------------------------------------------------------------
  // Local caches
  // ------------------------------------------------------------------

  Future<void> _cacheSession(SessionUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionCacheKey, jsonEncode(user.toJson()));
  }

  /// Drops the cached session.
  ///
  /// Used when an account is refused at sign-in. Without it the refusal is
  /// only skin deep: a session cached by an older build - one where admins
  /// did sign in here - would be restored on the next launch and walk
  /// straight past the check that just turned it away.
  Future<void> _clearCachedSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionCacheKey);
  }

  Future<SessionUser?> _readCachedSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_sessionCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return SessionUser.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  /// Auth UIDs of the operators attached to [schoolId].
  ///
  /// Admin-only in practice: the security rules let an admin read any user
  /// document, but an operator can only read their own, so this query is
  /// rejected for them. That is the correct shape - one school has no business
  /// enumerating another's staff.
  ///
  /// Used when opening a conversation, so the operator is actually a member
  /// and can see it. Without this the chat would exist but be invisible to the
  /// person it is addressed to.
  Future<List<String>> operatorUidsForSchool(String schoolId) async {
    if (!isBackendAvailable || schoolId.isEmpty) return const <String>[];

    try {
      final QuerySnapshot<Map<String, Object?>> snap = await _db
          .collection(kUsersCollection)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      return snap.docs
          .where(
            (QueryDocumentSnapshot<Map<String, Object?>> d) =>
                d.data()['active'] != false,
          )
          .map((QueryDocumentSnapshot<Map<String, Object?>> d) => d.id)
          .toList();
    } on FirebaseException {
      // A failed lookup must not block the admin from opening the chat; they
      // just get a conversation the operator cannot see yet, which the UI
      // reports rather than hiding.
      return const <String>[];
    }
  }

  /// Powers the school-name dropdown on the login screen. Only codes that have
  /// successfully signed in on this device are remembered, so it never leaks
  /// the organisation's full school list to an unauthenticated user.
  Future<List<String>> knownSchoolCodes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_knownSchoolsKey) ?? const <String>[];
  }

  Future<void> _rememberSchoolCode(String code) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> existing =
        prefs.getStringList(_knownSchoolsKey) ?? <String>[];
    final List<String> next = <String>[
      code,
      ...existing.where((String c) => c.toLowerCase() != code.toLowerCase()),
    ].take(10).toList();
    await prefs.setStringList(_knownSchoolsKey, next);
  }

  // ------------------------------------------------------------------

  String _describeAuthError(FirebaseAuthException e, UserRole role) {
    // Teacher and parent accounts sign in with an address; a school signs in
    // with its code. Naming the wrong one in the error is a small thing that
    // sends somebody hunting for a credential they were never issued.
    final String subject = role == UserRole.school
        ? 'school code'
        : 'email address';
    return switch (e.code) {
      'invalid-email' => 'That $subject is not valid.',
      'user-disabled' => 'This account has been disabled.',
      // Firebase deliberately collapses "no such user" and "wrong password"
      // into invalid-credential to avoid confirming which accounts exist.
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Wrong $subject or password.',
      'too-many-requests' =>
        'Too many failed attempts. Wait a few minutes and try again.',
      'network-request-failed' => 'No connection. You can still work offline - saved entries will sync later.',
      _ => e.message ?? 'Sign-in failed (${e.code}).',
    };
  }
}

/// Fire-and-forget helper. Named with a trailing underscore so it is obviously
/// not `package:async`'s `unawaited`, which the lint set would also accept -
/// this one additionally swallows errors, which is the behaviour we want for
/// telemetry-style writes.
void unawaited_(Future<void> future) {
  future.ignore();
}
