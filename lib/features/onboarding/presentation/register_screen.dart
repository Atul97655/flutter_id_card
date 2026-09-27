import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/onboarding/presentation/qr_scanner_screen.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: JoinTheme.header,
        foregroundColor: Colors.white,
        title: const Text('Create your account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const FadeSlideIn(
                      child: Text(
                        'This account is just you. Your school is added in the '
                        'next step, when you scan the code your office printed.',
                        style: TextStyle(fontSize: 13.5, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 22),

                    FadeSlideIn(
                      index: 1,
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          helperText:
                              'The office sees this in their pending list',
                        ),
                        validator: (String? v) =>
                            (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    FadeSlideIn(
                      index: 2,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
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
                    const SizedBox(height: 16),

                    FadeSlideIn(
                      index: 3,
                      child: TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => unawaited(_submit()),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 6 characters',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (String? v) => (v ?? '').length < 6
                            ? 'At least 6 characters'
                            : null,
                      ),
                    ),

                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _ErrorBox(message: _error!),
                    ],

                    const SizedBox(height: 26),
                    FadeSlideIn(
                      index: 4,
                      child: FilledButton(
                        style: JoinTheme.filledButton(),
                        onPressed: _busy ? null : () => unawaited(_submit()),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create account and scan'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => context.pop(),
                      child: const Text('I already have an account'),
                    ),
                  ],
                ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C6C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
