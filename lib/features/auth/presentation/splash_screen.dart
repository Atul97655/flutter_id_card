import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_theme.dart';
import 'package:flutter_id_card/shared/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Branding screen shown for a minimum of two seconds.
///
/// It doubles as the gate for session restore: the router leaves this route
/// alone, and we navigate onwards only once *both* the timer has elapsed and
/// the auth state has resolved. That avoids the flash of a login form for an
/// operator who is already signed in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const String routePath = '/';
  static const String routeName = 'splash';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const Duration _minimumDisplay = Duration(seconds: 2);

  Timer? _timer;
  bool _minimumElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumDisplay, () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
      _maybeNavigate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeNavigate() {
    if (_navigated || !_minimumElapsed || !mounted) return;

    final AsyncValue<SessionUser?> auth = ref.read(authControllerProvider);
    if (auth.isLoading) return;

    _navigated = true;
    final SessionUser? user = auth.value;
    // Admins go straight to their own panel. Landing them on the operator
    // home screen - which shows a school they do not belong to and a data-entry
    // flow they will never use - made a restored admin session look broken.
    context.go(switch (user) {
      null => '/login',
      final SessionUser u when u.isAdmin => '/admin',
      _ => '/home',
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-check on every auth transition; the timer covers the other direction.
    ref.listen<AsyncValue<SessionUser?>>(authControllerProvider, (
      AsyncValue<SessionUser?>? previous,
      AsyncValue<SessionUser?> next,
    ) {
      if (!next.isLoading) _maybeNavigate();
    });

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // The first thing anyone sees of the app. It used to appear fully
            // formed in one frame, which is the moment that set the tone for
            // the whole thing feeling static.
            const FadeSlideIn(
              offset: 22,
              duration: AppMotion.slow,
              child: AppLogo(size: 108, onDark: true),
            ),
            const SizedBox(height: AppTheme.gutter * 1.5),
            FadeSlideIn(
              index: 2,
              child: Text(
                'ID ENTITY',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              index: 4,
              child: Text(
                'School Identity Management',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const FadeSlideIn(
              index: 6,
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
