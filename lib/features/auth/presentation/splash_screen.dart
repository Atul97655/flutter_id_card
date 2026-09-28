import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_gradients.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
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

    return Scaffold(
      body: DecoratedBox(
        // The navy gradient, not a flat primary fill. This is the first thing
        // anyone sees of the app, and it is the moment that decides whether
        // the rest of it is going to look considered.
        decoration: const BoxDecoration(gradient: AppGradients.header),
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: -70,
              right: -70,
              child: _Glow(size: 280, color: Color(0x3D6E9BF0)),
            ),
            const Positioned(
              bottom: -110,
              left: -80,
              child: _Glow(size: 320, color: Color(0x337C4DDB)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // It used to appear fully formed in one frame, which is the
                  // moment that set the tone for the whole thing feeling
                  // static.
                  FadeSlideIn(
                    offset: 22,
                    duration: AppMotion.slow,
                    child: Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.4,
                        ),
                        boxShadow: AppShadows.floating,
                      ),
                      child: const Center(
                        child: AppLogo(size: 92, onDark: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeSlideIn(
                    index: 2,
                    child: Text(
                      'ID ENTITY',
                      style: AppTypography.displayOnDark.copyWith(
                        fontSize: 28,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    index: 4,
                    child: Text(
                      'School Identity Management',
                      style: AppTypography.displaySubOnDark.copyWith(
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                  const FadeSlideIn(
                    index: 6,
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.onDarkMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft radial bloom on the splash backdrop.
///
/// A radial gradient rather than a blurred circle: a BackdropFilter on the
/// very first frame of the app is the one place a dropped frame is certain to
/// be noticed.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
