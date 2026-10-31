import 'dart:async';

import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/data/otp_repository.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart'
    show AuthFailure;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<OtpRepository> otpRepositoryProvider = Provider<OtpRepository>(
  (Ref ref) => OtpRepository(),
);

/// Where the person is in the code flow.
enum OtpStage {
  /// Typing their address.
  email,

  /// A code has been asked for; typing the six digits.
  code,

  /// Verified and signed in. The router takes over from here.
  signedIn,
}

/// Everything the two screens need to draw themselves.
class OtpState {
  const OtpState({
    this.stage = OtpStage.email,
    this.email = '',
    this.busy = false,
    this.error,
    this.resendIn = Duration.zero,
  });

  final OtpStage stage;
  final String email;
  final bool busy;
  final String? error;

  /// How long until Resend becomes live again. Counts down once a second.
  final Duration resendIn;

  bool get canResend => !busy && resendIn == Duration.zero;

  OtpState copyWith({
    OtpStage? stage,
    String? email,
    bool? busy,
    Duration? resendIn,
    String? error,
    bool clearError = false,
  }) => OtpState(
    stage: stage ?? this.stage,
    email: email ?? this.email,
    busy: busy ?? this.busy,
    resendIn: resendIn ?? this.resendIn,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives email-code sign-in.
///
/// The countdown lives here rather than in the OTP screen because it has to
/// survive the screen: a rotation, or the app being backgrounded while the
/// person goes to read the email, would otherwise reset it to zero and offer
/// a Resend the server is about to refuse.
///
/// The number it counts down from comes from the server's response, not from
/// a constant here. A client-side cooldown is a courtesy, not a limit - the
/// real one is enforced in `sendOtp`, and if the two disagree the server
/// wins. Taking its number means the button goes live exactly when it will
/// start working.
class OtpController extends Notifier<OtpState> {
  Timer? _ticker;

  @override
  OtpState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const OtpState();
  }

  OtpRepository get _otp => ref.read(otpRepositoryProvider);

  /// Clears a stale message as soon as the person starts fixing their input.
  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  /// Back to the address field, e.g. "wrong email?" on the code screen.
  void editEmail() {
    _ticker?.cancel();
    state = OtpState(email: state.email);
  }

  /// Asks for a code and, on success, moves to the code screen.
  Future<bool> requestCode(String rawEmail) async {
    final String email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) {
      state = state.copyWith(error: 'Enter your email address');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      state = state.copyWith(error: 'Enter a valid email address');
      return false;
    }

    state = state.copyWith(busy: true, email: email, clearError: true);
    try {
      final Duration cooldown = await _otp.requestCode(email);
      state = state.copyWith(
        stage: OtpStage.code,
        busy: false,
        clearError: true,
      );
      _startCountdown(cooldown);
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  /// Asks for another code for the address already entered.
  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final Duration cooldown = await _otp.requestCode(state.email);
      state = state.copyWith(busy: false, clearError: true);
      _startCountdown(cooldown);
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      // A refusal is almost always the cooldown, and the server says how
      // long is left in its message. Restarting the local countdown stops
      // the button inviting a second refusal straight away.
      _startCountdown(const Duration(seconds: 30));
    }
  }

  /// Checks the code and, on success, completes the session.
  Future<bool> submitCode(String rawCode) async {
    final String code = rawCode.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      state = state.copyWith(error: 'Enter the six digits from the email');
      return false;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      await _otp.submitCode(email: state.email, code: code);
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }

    // Signed in with Firebase; now turn that into this app's session, which
    // is also where an admin account is refused.
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .completeCodeSignIn();

    if (!ok) {
      final Object? error = ref.read(authControllerProvider).error;
      state = state.copyWith(
        busy: false,
        error: error is AuthFailure
            ? error.message
            : 'Could not complete sign-in. Try again.',
      );
      return false;
    }

    _ticker?.cancel();
    state = state.copyWith(stage: OtpStage.signedIn, busy: false);
    return true;
  }

  void _startCountdown(Duration from) {
    _ticker?.cancel();
    state = state.copyWith(resendIn: from);
    if (from == Duration.zero) return;

    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      final int left = state.resendIn.inSeconds - 1;
      if (left <= 0) {
        t.cancel();
        state = state.copyWith(resendIn: Duration.zero);
      } else {
        state = state.copyWith(resendIn: Duration(seconds: left));
      }
    });
  }
}

final NotifierProvider<OtpController, OtpState> otpControllerProvider =
    NotifierProvider<OtpController, OtpState>(OtpController.new);
