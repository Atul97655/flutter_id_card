import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/parent/application/parent_strings.dart';
import 'package:flutter_id_card/features/parent/presentation/widgets/parent_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign up or sign in as a parent or student - one screen, two modes.
///
/// A parent's account is complete the moment it exists, because they choose
/// the school each time they make a card. So there is no QR code and no
/// waiting room here: once the session changes, the router's redirect carries
/// them to the home screen.
///
/// Sign-in and sign-up share a screen on purpose. The two forms are nearly the
/// same, and a parent who picked the wrong one only has to tap a link, not
/// back out and find the other door.
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

  bool _signIn = false;
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

  Future<void> _submit(ParentStrings s) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final AuthController auth = ref.read(authControllerProvider.notifier);
    final bool ok = _signIn
        // The operator sign-in already takes an email in place of a school
        // code, and accepts any non-admin account - parents included.
        ? await auth.signInAsSchool(
            schoolCode: _email.text,
            password: _password.text,
          )
        : await auth.registerParent(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
          );

    if (!mounted) return;

    if (!ok) {
      final Object? err = ref.read(authControllerProvider).error;
      setState(() {
        _busy = false;
        _error = err is AuthFailure ? err.message : s.genericAuthError;
      });
    }
    // On success there is nothing to do: the session changed, and the
    // router's redirect moves a signed-in parent off this screen.
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ParentColors.inkSoft),
      suffixIcon: suffix,
      filled: true,
      fillColor: ParentColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: border(ParentColors.line),
      focusedBorder: border(ParentColors.brand, 2),
      errorBorder: border(ParentColors.danger),
      focusedErrorBorder: border(ParentColors.danger, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ParentStrings s = ref.watch(parentStringsProvider);

    return Scaffold(
      body: ParentBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: _busy ? null : () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: ParentColors.ink,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                          ),
                          const Spacer(),
                          const LanguageToggle(),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark(size: 64),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _signIn ? s.welcomeBack : s.getStarted,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: ParentColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _signIn ? s.signInSubtitle : s.signUpSubtitle,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.4,
                          color: ParentColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (!_signIn) ...<Widget>[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            s.yourName,
                            Icons.person_outline_rounded,
                          ),
                          validator: (String? v) =>
                              (v ?? '').trim().isEmpty ? s.enterName : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: _decoration(
                          s.email,
                          Icons.alternate_email_rounded,
                        ),
                        validator: (String? v) {
                          final String value = (v ?? '').trim();
                          if (value.isEmpty) return s.enterEmail;
                          if (!value.contains('@')) return s.badEmail;
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => unawaited(_submit(s)),
                        decoration: _decoration(
                          s.password,
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: ParentColors.inkSoft,
                            ),
                          ),
                        ).copyWith(helperText: _signIn ? null : s.passwordHint),
                        validator: (String? v) {
                          final String value = v ?? '';
                          if (_signIn) return value.isEmpty ? s.shortPassword : null;
                          return value.length < 6 ? s.shortPassword : null;
                        },
                      ),

                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ParentColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline_rounded,
                                color: ParentColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: ParentColors.danger,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 26),
                      BigButton(
                        label: _signIn ? s.signIn : s.createAccount,
                        icon: _signIn
                            ? Icons.login_rounded
                            : Icons.arrow_forward_rounded,
                        busy: _busy,
                        onPressed: () => unawaited(_submit(s)),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _signIn = !_signIn;
                                _error = null;
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _signIn ? s.newHere : s.haveAccount,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: ParentColors.brand,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
