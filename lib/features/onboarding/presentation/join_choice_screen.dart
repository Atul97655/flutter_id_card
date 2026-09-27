import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/presentation/login_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/register_screen.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';
import 'package:go_router/go_router.dart';

/// Screen 15 — the two ways into the app.
///
/// A teacher arrives here holding one of two things: credentials the office
/// typed out for them, or a printed QR code on the staffroom wall. The screen
/// asks which, and says plainly where both come from, because the third case
/// - holding neither - is common and otherwise ends in a phone call.
class JoinChoiceScreen extends StatelessWidget {
  const JoinChoiceScreen({super.key});

  static const String routePath = '/join';
  static const String routeName = 'join';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const FadeSlideIn(child: _Badge()),
                  const SizedBox(height: 26),
                  FadeSlideIn(
                    index: 1,
                    child: Text(
                      'Student ID Cards',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const FadeSlideIn(
                    index: 2,
                    child: Text(
                      'Capture a student photo, fill the details, send it to '
                      'the office. That is the whole job.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 34),
                  FadeSlideIn(
                    index: 3,
                    child: FilledButton(
                      style: JoinTheme.filledButton(),
                      onPressed: () => context.push(LoginScreen.routePath),
                      child: const Text('Sign in with my details'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 4,
                    child: OutlinedButton.icon(
                      style: JoinTheme.outlinedButton(),
                      // Registration, not the camera. A scan writes a join
                      // request keyed by the teacher's own auth uid, and
                      // there is no uid until there is an account - the
                      // register screen goes straight on to the scanner once
                      // there is one.
                      onPressed: () => context.push(RegisterScreen.routePath),
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Scan my school QR code'),
                    ),
                  ),
                  const SizedBox(height: 26),
                  // The third case: a teacher with neither. Naming who issues
                  // both is what stops this becoming a call to the office
                  // asking how to get in.
                  const FadeSlideIn(
                    index: 5,
                    child: Text(
                      'Do not have either? Ask your school office — accounts '
                      'and QR codes are issued by them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.5),
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

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(
        color: JoinTheme.header,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.badge_outlined, color: Colors.white, size: 38),
    );
  }
}
