import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart'
    show AuthFailure;
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';

/// Sign-in by a code emailed to the person, rather than by a password.
///
/// Everything that decides anything happens in the `sendOtp` / `verifyOtp`
/// Cloud Functions - see functions/src/index.ts. This class is the wire: it
/// calls them, turns their error codes into sentences somebody standing in a
/// school office can act on, and exchanges the custom token for a session.
///
/// The region is pinned because a callable with the wrong region does not
/// fail loudly - it resolves to a URL that does not exist and times out,
/// which reads as "no connection" and sends the next person debugging the
/// wrong thing entirely.
class OtpRepository {
  OtpRepository({FirebaseFunctions? functions, FirebaseAuth? auth})
    : _functionsOverride = functions,
      _authOverride = auth;

  final FirebaseFunctions? _functionsOverride;
  final FirebaseAuth? _authOverride;

  /// Must match `REGION` in functions/src/index.ts.
  static const String region = 'asia-south1';

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instanceFor(region: region);

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get isBackendAvailable => FirebaseBootstrap.instance.isReady;

  /// Asks for a code to be emailed.
  ///
  /// Returns how long to wait before the Resend button becomes live again.
  /// The server decides that number, not the screen: a cooldown the client
  /// invents is one a second device, or a reinstall, walks straight past.
  ///
  /// Succeeds whether or not the address has an account. That is the
  /// server's choice and it is deliberate - answering differently would make
  /// this an oracle for which addresses are registered - so the screen that
  /// follows must not promise an email has arrived, only that one was sent
  /// if the account exists.
  Future<Duration> requestCode(String email) async {
    if (!isBackendAvailable) {
      throw const AuthFailure(
        'Cannot reach the server. Check your connection and try again.',
      );
    }

    try {
      final HttpsCallableResult<Object?> result = await _functions
          .httpsCallable('sendOtp')
          .call<Object?>(<String, Object?>{'email': email});

      final Object? data = result.data;
      final int seconds = data is Map && data['resendInSeconds'] is int
          ? data['resendInSeconds'] as int
          : 60;
      return Duration(seconds: seconds);
    } on FirebaseFunctionsException catch (e) {
      throw AuthFailure(_describeSend(e));
    } on Object {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  /// Checks a code and signs in on success.
  ///
  /// The custom token is exchanged immediately and never returned to the
  /// caller. It is a bearer credential with a one-hour life; the fewer places
  /// it can be held, logged or accidentally persisted, the better.
  Future<void> submitCode({
    required String email,
    required String code,
  }) async {
    if (!isBackendAvailable) {
      throw const AuthFailure(
        'Cannot reach the server. Check your connection and try again.',
      );
    }

    final String token;
    try {
      final HttpsCallableResult<Object?> result = await _functions
          .httpsCallable('verifyOtp')
          .call<Object?>(<String, Object?>{'email': email, 'code': code});

      final Object? data = result.data;
      final Object? raw = data is Map ? data['token'] : null;
      if (raw is! String || raw.isEmpty) {
        throw const AuthFailure('Sign-in failed. Ask for a new code.');
      }
      token = raw;
    } on FirebaseFunctionsException catch (e) {
      throw AuthFailure(_describeVerify(e));
    } on AuthFailure {
      rethrow;
    } on Object {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    try {
      await _auth.signInWithCustomToken(token);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(
        e.code == 'invalid-custom-token' || e.code == 'custom-token-mismatch'
            // Almost always a configuration fault rather than anything the
            // person did: the functions minting tokens for a different
            // project than the app is signing into.
            ? 'Sign-in is misconfigured for this app. Tell the office.'
            : 'Could not complete sign-in. Try again.',
      );
    }
  }

  /// The server's own message, when it wrote one worth showing.
  ///
  /// `sendOtp` composes its rate-limit messages with the actual number of
  /// seconds left, which is more useful than anything that can be written
  /// here. The fallbacks cover the codes it never raises on purpose.
  static String _describeSend(FirebaseFunctionsException e) {
    return switch (e.code) {
      'invalid-argument' =>
        e.message ?? 'That does not look like an email address.',
      'resource-exhausted' =>
        e.message ?? 'Too many codes requested. Try again shortly.',
      'unavailable' =>
        e.message ?? 'Could not send the code just now. Try again.',
      'unauthenticated' => 'Sign-in is not available right now.',
      'internal' =>
        'Something went wrong sending the code. Try again in a moment.',
      _ => e.message ?? 'Could not send the code. Try again.',
    };
  }

  static String _describeVerify(FirebaseFunctionsException e) {
    return switch (e.code) {
      // Wrong code. The server counts down the tries in its message, so it
      // is worth more than anything generic written here.
      'permission-denied' => e.message ?? 'That code is not right.',
      'deadline-exceeded' ||
      'not-found' => e.message ?? 'That code has expired. Ask for a new one.',
      'resource-exhausted' =>
        e.message ?? 'Too many wrong attempts. Ask for a new code.',
      'invalid-argument' => 'Enter the six digits from the email.',
      _ => e.message ?? 'Could not check that code. Try again.',
    };
  }
}
