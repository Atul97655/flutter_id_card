import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_id_card/features/auth/domain/managed_user.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  static const String _sessionCacheKey = 'cached_session_user';
  static const String _knownSchoolsKey = 'known_school_codes';
  static const String _cachedUsersKey = 'cached_managed_users';

  StreamController<List<ManagedUser>>? _usersController;
  StreamSubscription<QuerySnapshot<Map<String, Object?>>>? _firestoreUsersSub;

  void dispose() {
    _firestoreUsersSub?.cancel();
    _firestoreUsersSub = null;
    _usersController?.close();
  }

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

  Future<SessionUser> signInAsAdmin({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty) {
      throw const AuthFailure('Enter your admin email');
    }
    return _signIn(
      email: email.trim().toLowerCase(),
      password: password,
      expectedRole: UserRole.admin,
    );
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

    // Compared by privilege class, not exact role. The operator tab accepts
    // both School and Teacher accounts - they are the same data scope, and an
    // exact-equality check here would lock every Teacher account out of the
    // only tab it is allowed to use.
    final bool roleMatches = expectedRole == UserRole.admin
        ? session.role == UserRole.admin
        : session.role.isOperator;

    if (!roleMatches) {
      await _auth.signOut();
      throw AuthFailure(
        expectedRole == UserRole.admin
            ? 'This account is not an admin account.'
            : 'This is an admin account - use the Admin tab to sign in.',
      );
    }
    if (expectedRole != UserRole.admin && !session.canEnterData) {
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
      final DocumentSnapshot<Map<String, Object?>> byUid =
          await _db.collection(kUsersCollection).doc(fbUser.uid).get();
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
      await _db.collection(kUsersCollection).doc(uid).set(
        <String, Object?>{'lastLoginDate': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
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
    if (cached != null && cached.uid == fbUser.uid) {
      // Refresh in the background so a role change lands on the next frame
      // without making the operator wait for it now.
      unawaited_(_refreshCachedProfile(fbUser));
      return cached;
    }

    try {
      final SessionUser fresh = await _loadProfile(fbUser);
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
      throw const AuthFailure('The new password must be at least 6 characters.');
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
      throw AuthFailure(
        switch (e.code) {
          'wrong-password' ||
          'invalid-credential' =>
            'That is not your current password.',
          'too-many-requests' =>
            'Too many attempts. Wait a few minutes and try again.',
          'network-request-failed' =>
            'No connection. Try again when you are online.',
          _ => 'Could not verify your current password (${e.code}).',
        },
      );
    }

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(
        switch (e.code) {
          'weak-password' => 'That password is too easy to guess.',
          'requires-recent-login' =>
            'Sign out and sign in again, then change the password.',
          _ => 'Could not change the password (${e.code}).',
        },
      );
    }
  }

  // ------------------------------------------------------------------
  // Local caches
  // ------------------------------------------------------------------

  Future<void> _cacheSession(SessionUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionCacheKey, jsonEncode(user.toJson()));
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
          .where((QueryDocumentSnapshot<Map<String, Object?>> d) =>
              d.data()['active'] != false)
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
    final List<String> existing = prefs.getStringList(_knownSchoolsKey) ?? <String>[];
    final List<String> next = <String>[
      code,
      ...existing.where((String c) => c.toLowerCase() != code.toLowerCase()),
    ].take(10).toList();
    await prefs.setStringList(_knownSchoolsKey, next);
  }

  // ------------------------------------------------------------------
  // Admin User Management (Accounts & Access Control)
  // ------------------------------------------------------------------

  Future<List<ManagedUser>> _getOrSeedUsers() async {
    List<ManagedUser> cached = await _readCachedUsers();
    if (cached.isEmpty) {
      final List<ManagedUser> seeds = <ManagedUser>[
        const ManagedUser(
          uid: 'admin-seed',
          email: 'admin@idcardx.app',
          role: UserRole.admin,
          displayName: 'System Admin',
          active: true,
        ),
        const ManagedUser(
          uid: 'school-seed',
          email: 'shc@schools.idcardx.app',
          role: UserRole.school,
          schoolId: 'demo-school',
          displayName: 'Sacred Heart Convent',
          active: true,
        ),
      ];
      await _cacheUsers(seeds);
      cached = seeds;
    }
    return cached;
  }

  /// Watches all registered user accounts.
  Stream<List<ManagedUser>> watchUsers() {
    _usersController ??= StreamController<List<ManagedUser>>.broadcast(
      onListen: () {
        _getOrSeedUsers().then((List<ManagedUser> u) {
          if (!(_usersController?.isClosed ?? true)) {
            _usersController?.add(u);
          }
        });
        if (isBackendAvailable && _firestoreUsersSub == null) {
          _firestoreUsersSub = _db
              .collection(kUsersCollection)
              .snapshots()
              .listen((QuerySnapshot<Map<String, Object?>> snap) {
            if (snap.docs.isEmpty) return;
            final List<ManagedUser> list = snap.docs.map((QueryDocumentSnapshot<Map<String, Object?>> d) {
              return ManagedUser.fromFirestore(d.id, d.data());
            }).toList();
            if (!(_usersController?.isClosed ?? true)) {
              _usersController?.add(list);
            }
            unawaited_(_cacheUsers(list));
          }, onError: (Object _) {
            // Swallow offline / stream errors gracefully
          });
        }
      },
    );

    // Also push current data immediately
    _getOrSeedUsers().then((List<ManagedUser> u) {
      if (!(_usersController?.isClosed ?? true)) {
        _usersController?.add(u);
      }
    });

    return _usersController!.stream;
  }

  Future<void> createUserAccount({
    required String email,
    required String password,
    required UserRole role,
    required String? schoolId,
    required String displayName,
  }) async {
    if (email.trim().isEmpty) {
      throw const AuthFailure('Email or school login ID is required');
    }
    if (password.trim().length < 6) {
      throw const AuthFailure('Password must be at least 6 characters');
    }
    if (role == UserRole.school && (schoolId == null || schoolId.trim().isEmpty)) {
      throw const AuthFailure('Select a school for this operator');
    }

    final String normalizedEmail = schoolCodeToEmail(email);
    final String uid = const Uuid().v4();
    final DateTime now = DateTime.now();

    final ManagedUser newUser = ManagedUser(
      uid: uid,
      email: normalizedEmail,
      role: role,
      schoolId: schoolId,
      displayName: displayName.trim().isEmpty ? normalizedEmail : displayName.trim(),
      active: true,
      createdAt: now,
    );

    if (isBackendAvailable) {
      try {
        await _db
            .collection(kUsersCollection)
            .doc(uid)
            .set(newUser.toFirestoreMap())
            .timeout(const Duration(seconds: 3));
      } on Object {
        // Offline or network timeout - account is preserved locally in cache
      }
    }

    // Always update local cache
    final List<ManagedUser> current = await _readCachedUsers();
    final List<ManagedUser> updated = <ManagedUser>[
      newUser,
      ...current.where((ManagedUser u) => u.email != normalizedEmail),
    ];
    await _cacheUsers(updated);
    if (!(_usersController?.isClosed ?? true)) {
      _usersController?.add(updated);
    }
  }

  Future<void> toggleUserActive(String uid, bool active) async {
    if (isBackendAvailable) {
      try {
        await _db
            .collection(kUsersCollection)
            .doc(uid)
            .update(<String, Object?>{
              'active': active,
            })
            .timeout(const Duration(seconds: 3));
      } on Object {
        // Offline or network timeout - status updated in local cache
      }
    }

    final List<ManagedUser> current = await _readCachedUsers();
    final List<ManagedUser> updated = current.map((ManagedUser u) {
      if (u.uid == uid) return u.copyWith(active: active);
      return u;
    }).toList();
    await _cacheUsers(updated);
    if (!(_usersController?.isClosed ?? true)) {
      _usersController?.add(updated);
    }
  }

  Future<void> _cacheUsers(List<ManagedUser> users) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(users.map((ManagedUser u) => u.toJson()).toList());
    await prefs.setString(_cachedUsersKey, raw);
  }

  Future<List<ManagedUser>> _readCachedUsers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_cachedUsersKey);
    if (raw == null || raw.isEmpty) return const <ManagedUser>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const <ManagedUser>[];
      return decoded
          .whereType<Map<String, Object?>>()
          .map(ManagedUser.fromJson)
          .toList();
    } on FormatException {
      return const <ManagedUser>[];
    }
  }

  // ------------------------------------------------------------------

  String _describeAuthError(FirebaseAuthException e, UserRole role) {
    final String subject = role == UserRole.admin ? 'admin email' : 'school code';
    return switch (e.code) {
      'invalid-email' => 'That $subject is not valid.',
      'user-disabled' => 'This account has been disabled.',
      // Firebase deliberately collapses "no such user" and "wrong password"
      // into invalid-credential to avoid confirming which accounts exist.
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Wrong $subject or password.',
      'too-many-requests' =>
        'Too many failed attempts. Wait a few minutes and try again.',
      'network-request-failed' =>
        'No connection. You can still work offline - saved entries will sync later.',
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
