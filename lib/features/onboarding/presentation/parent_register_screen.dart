import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
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

/// Creating an account as a parent or student.
///
/// The counterpart of `RegisterScreen`, without the second step. A teacher's
/// account is useless until the office attaches a school to it; a parent's is
/// complete the moment it exists, because they choose the school each time
/// they make a card. So this screen has no QR code and no waiting room - once
/// the account is made, the router's redirect carries them to the home screen.
class ParentRegisterScreen extends ConsumerStatefulWidget {
  const ParentRegisterScreen({super.key});

  static const String routePath = '/join/parent';
  static const String routeName = 'join-parent';

  @override
  ConsumerState<ParentRegisterScreen> createState() =>
      _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends ConsumerState<ParentRegisterScreen> {
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
        .registerParent(
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
    }
    // On success there is nothing to do: the session changed, and the
    // router's redirect moves a signed-in parent off this screen.
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backdrop: GlassBackdrop.chat,
      header: GlassHeader(
        title: 'Create your account',
        subtitle: 'For parents and students',
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
                              'Make an account, pick your school, add your '
                              "child's photo and details, and send. The "
                              'school office prints the card.',
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
                      placeholder: 'Parent or student name',
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
                    Text(
                      _error!,
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.rejected,
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),
                  FadeSlideIn(
                    index: 4,
                    child: GlassButton(
                      label: 'Create account',
                      icon: Icons.check_rounded,
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
