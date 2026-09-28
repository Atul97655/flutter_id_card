import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/onboarding/presentation/qr_scanner_screen.dart';
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

/// Creating the account that a QR code then attaches to a school.
///
/// Not in the screen pack, and it has to exist anyway. The pack shows a
/// teacher scanning a code, but a scan writes a join request keyed by the
/// teacher's own auth uid - there is no such uid until there is an account,
/// and the office cannot create one for them: minting a Firebase Auth user
/// from the browser signs the admin out of their own session.
///
/// So this is the missing first step, and it is deliberately unglamorous.
/// The account it produces can read nothing at all. Everything that grants
/// access happens later, in the office, when somebody approves the join.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const String routePath = '/join/register';
  static const String routeName = 'join-register';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .registerTeacher(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );

    if (!mounted) return;

    if (!ok) {
      final Object? err = ref.read(authControllerProvider).error;
      setState(() {
        _busy = false;
        _error = err is AuthFailure
            ? err.message
            : 'Could not create the account. Try again.';
      });
      return;
    }

    // Straight to the camera. The account on its own is useless - the only
    // reason to have made it was to scan a code with it.
    context.pushReplacement(QrScannerScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backdrop: GlassBackdrop.chat,
      header: GlassHeader(
        title: 'Create your account',
        subtitle: 'Step 1 of 2',
        // Always present, so the header does not change shape mid-save.
        onBack: () {
          if (!_busy) context.pop();
        },
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FadeSlideIn(
                    child: GlassSurface(
                      radius: AppRadius.fieldR,
                      fill: AppColors.chatTheirs,
                      shadows: AppShadows.subtle,
                      sheen: false,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.chatDeep,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'This account is just you. Your school is added '
                              'in the next step, when you scan the code your '
                              'office printed.',
                              style: AppTypography.support.copyWith(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.inkBody,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  FadeSlideIn(
                    index: 1,
                    child: GlassTextField(
                      label: 'Your name',
                      icon: Icons.person_outline,
                      controller: _name,
                      placeholder: 'As the office knows you',
                      helperText: 'The office sees this in their pending list',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (String? v) =>
                          (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  FadeSlideIn(
                    index: 2,
                    child: GlassTextField(
                      label: 'Email',
                      icon: Icons.alternate_email,
                      controller: _email,
                      placeholder: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (String? v) {
                        final String value = (v ?? '').trim();
                        if (value.isEmpty) return 'Enter your email';
                        if (!value.contains('@')) {
                          return 'That does not look like an email address';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  FadeSlideIn(
                    index: 3,
                    child: GlassTextField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: _password,
                      obscureText: _obscure,
                      helperText: 'At least 6 characters',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_submit()),
                      trailing: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 19,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      validator: (String? v) =>
                          (v ?? '').length < 6 ? 'At least 6 characters' : null,
                    ),
                  ),

                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _ErrorBox(message: _error!),
                  ],

                  const SizedBox(height: 26),
                  FadeSlideIn(
                    index: 4,
                    child: GlassButton(
                      label: 'Create account and scan',
                      icon: Icons.qr_code_scanner,
                      busy: _busy,
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppColors.chatAccent,
                          AppColors.chatDeep,
                        ],
                      ),
                      onPressed: _busy ? null : () => unawaited(_submit()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _busy ? null : () => context.pop(),
                    child: Text(
                      'I already have an account',
                      style: AppTypography.badge.copyWith(
                        fontSize: 13.5,
                        color: AppColors.chatDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.fieldR,
      fill: AppColors.rejectedTint.withValues(alpha: 0.92),
      borderColor: AppColors.rejected.withValues(alpha: 0.26),
      shadows: const <BoxShadow>[],
      sheen: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppColors.rejected, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.rejected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
