import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/presentation/login_screen.dart';
import 'package:flutter_id_card/features/onboarding/presentation/register_screen.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
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
    return GlassScaffold(
      // The chat backdrop, because the whole joining flow wears the green
      // chrome the screen spec gives it.
      backdrop: GlassBackdrop.chat,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 32,
          ),
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
                    style: AppTypography.display.copyWith(fontSize: 27),
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  index: 2,
                  child: Text(
                    'Capture a student photo, fill the details, send it to '
                    'the office. That is the whole job.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                FadeSlideIn(
                  index: 3,
                  child: GlassButton(
                    label: 'Sign in with my details',
                    icon: Icons.login_rounded,
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
                    ),
                    onPressed: () => context.push(LoginScreen.routePath),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  index: 4,
                  child: _SecondaryAction(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan my school QR code',
                    // Registration, not the camera. A scan writes a join
                    // request keyed by the teacher's own auth uid, and there
                    // is no uid until there is an account - the register
                    // screen goes straight on to the scanner once there is
                    // one.
                    onTap: () => context.push(RegisterScreen.routePath),
                  ),
                ),
                const SizedBox(height: 26),
                // The third case: a teacher with neither. Naming who issues
                // both is what stops this becoming a call to the office
                // asking how to get in.
                FadeSlideIn(
                  index: 5,
                  child: Text(
                    'Do not have either? Ask your school office — accounts '
                    'and QR codes are issued by them.',
                    textAlign: TextAlign.center,
                    style: AppTypography.support.copyWith(
                      fontSize: 12.5,
                      height: 1.5,
                    ),
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

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
        ),
        boxShadow: AppShadows.glow(AppColors.chatDeep),
      ),
      child: const Icon(
        Icons.badge_outlined,
        color: AppColors.onDark,
        size: 42,
      ),
    );
  }
}

/// The second of two equally valid routes in.
///
/// A glass pill rather than an outlined button: the two actions here are not
/// primary-and-fallback, they are two kinds of teacher, and an outline on a
/// translucent panel reads as disabled rather than as secondary.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      height: 56,
      radius: BorderRadius.circular(AppRadius.pill),
      fill: AppColors.glassFillStrong,
      borderColor: AppColors.chatDeep.withValues(alpha: 0.28),
      shadows: AppShadows.subtle,
      sheen: false,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.chatDeep),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.button.copyWith(color: AppColors.chatDeep),
          ),
        ],
      ),
    );
  }
}
