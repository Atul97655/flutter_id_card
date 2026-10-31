import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_id_card/features/auth/application/otp_controller.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign in with a code emailed to you, in two screens.
///
/// They live in one file because they are one flow and share one controller;
/// splitting them would mean reading two files to follow a single sequence of
/// four taps.
///
/// Neither screen navigates on success by itself. Signing in changes the
/// session, the router's redirect reacts to that, and the person lands
/// wherever their account belongs - home for an operator, the waiting screen
/// for a teacher the office has not approved yet. A `context.go('/home')`
/// here would be a second opinion about that, and it would be wrong for the
/// teacher.

// ---------------------------------------------------------------------------
// Screen one: the address
// ---------------------------------------------------------------------------

class EmailCodeRequestScreen extends ConsumerStatefulWidget {
  const EmailCodeRequestScreen({super.key});

  static const String routePath = '/login/code';
  static const String routeName = 'login-code';

  @override
  ConsumerState<EmailCodeRequestScreen> createState() =>
      _EmailCodeRequestScreenState();
}

class _EmailCodeRequestScreenState
    extends ConsumerState<EmailCodeRequestScreen> {
  final TextEditingController _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(otpControllerProvider).email;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final bool ok = await ref
        .read(otpControllerProvider.notifier)
        .requestCode(_email.text);
    if (!ok || !mounted) return;
    await context.push(EmailCodeEntryScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final OtpState otp = ref.watch(otpControllerProvider);

    return GlassScaffold(
      child: _Shell(
        title: 'Sign in with a code',
        subtitle:
            'We will email you a six-digit code. No password to remember.',
        onBack: () => Navigator.of(context).maybePop(),
        children: <Widget>[
          GlassTextField(
            label: 'Email address',
            icon: Icons.alternate_email,
            controller: _email,
            enabled: !otp.busy,
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onChanged: (_) =>
                ref.read(otpControllerProvider.notifier).clearError(),
            onSubmitted: (_) => otp.busy ? null : _submit(),
          ),
          _ErrorSlot(message: otp.error),
          const SizedBox(height: AppSpacing.xl),
          GlassButton(
            label: otp.busy ? 'Sending...' : 'Email me a code',
            icon: Icons.mail_outline,
            trailingIcon: otp.busy ? null : Icons.arrow_forward,
            busy: otp.busy,
            onPressed: otp.busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen two: the code
// ---------------------------------------------------------------------------

class EmailCodeEntryScreen extends ConsumerStatefulWidget {
  const EmailCodeEntryScreen({super.key});

  static const String routePath = '/login/code/verify';
  static const String routeName = 'login-code-verify';

  @override
  ConsumerState<EmailCodeEntryScreen> createState() =>
      _EmailCodeEntryScreenState();
}

class _EmailCodeEntryScreenState extends ConsumerState<EmailCodeEntryScreen> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref.read(otpControllerProvider.notifier).submitCode(_code.text);
    // No navigation on success. The session changed; the router decides.
  }

  @override
  Widget build(BuildContext context) {
    final OtpState otp = ref.watch(otpControllerProvider);

    return GlassScaffold(
      child: _Shell(
        title: 'Enter the code',
        // Deliberately "if there is an account". The server will not say
        // whether the address is registered, so neither can this screen -
        // promising an email that is never coming would be worse than
        // hedging.
        subtitle:
            'If there is an account for ${otp.email}, a six-digit code is on '
            'its way. It expires in five minutes.',
        onBack: () => Navigator.of(context).maybePop(),
        children: <Widget>[
          GlassTextField(
            label: 'Six-digit code',
            icon: Icons.password_outlined,
            controller: _code,
            enabled: !otp.busy,
            placeholder: '000000',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (String value) {
              ref.read(otpControllerProvider.notifier).clearError();
              // Submit itself on the sixth digit. The alternative is typing
              // six characters and then hunting for a button, which on a
              // phone means the keyboard is covering it.
              if (value.length == 6 && !otp.busy) _submit();
            },
            onSubmitted: (_) => otp.busy ? null : _submit(),
          ),
          _ErrorSlot(message: otp.error),
          const SizedBox(height: AppSpacing.lg),
          _ResendRow(
            resendIn: otp.resendIn,
            enabled: otp.canResend,
            onResend: () => ref.read(otpControllerProvider.notifier).resend(),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassButton(
            label: otp.busy ? 'Checking...' : 'Sign in',
            icon: Icons.login_rounded,
            trailingIcon: otp.busy ? null : Icons.arrow_forward,
            busy: otp.busy,
            onPressed: otp.busy ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: otp.busy
                  ? null
                  : () {
                      ref.read(otpControllerProvider.notifier).editEmail();
                      Navigator.of(context).maybePop();
                    },
              child: const Text('Use a different address'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// Resend, with the wait stated rather than implied.
///
/// A disabled button with no explanation reads as broken. The seconds are the
/// whole message: they say the app is working and when to try again.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.resendIn,
    required this.enabled,
    required this.onResend,
  });

  final Duration resendIn;
  final bool enabled;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final int seconds = resendIn.inSeconds;

    // Wrap, not Row. The two halves sit side by side when they fit and
    // stack when they do not, which they stop doing on a narrow phone with
    // the system text size turned up - common among the people using this.
    // A Row here overflowed by 90 pixels the first time it met a 400pt
    // screen, and an overflow is content nobody can read.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: <Widget>[
        Text(
          'No code yet?',
          style: AppTypography.support.copyWith(fontSize: 13),
        ),
        if (enabled)
          TextButton(
            onPressed: onResend,
            child: const Text('Send another'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              // Counted in seconds the whole way. "in a minute" is vaguer
              // than "in 47 seconds" and no shorter to read.
              seconds > 0 ? 'Send another in ${seconds}s' : 'Sending...',
              style: AppTypography.support.copyWith(
                fontSize: 13,
                color: AppColors.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorSlot extends StatelessWidget {
  const _ErrorSlot({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SmoothSwitcher(
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: ValueKey<String>(message!),
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: GlassSurface(
                radius: AppRadius.fieldR,
                fill: AppColors.rejectedTint.withValues(alpha: 0.92),
                borderColor: AppColors.rejected.withValues(alpha: 0.26),
                shadows: const <BoxShadow>[],
                sheen: false,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.rejected,
                      size: 19,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        message!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.rejected,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The scrolling, centred panel both screens sit in.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onTap: onBack,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTypography.display.copyWith(fontSize: 26)),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle, style: AppTypography.displaySub),
                const SizedBox(height: AppSpacing.xl),
                GlassSurface(
                  radius: AppRadius.panelR,
                  fill: AppColors.glassFillStrong,
                  shadows: AppShadows.lifted,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
