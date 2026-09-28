import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/presentation/home_screen.dart';
import 'package:flutter_id_card/features/onboarding/application/join_providers.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_id_card/shared/theme/app_colors.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/app_shadows.dart';
import 'package:flutter_id_card/shared/theme/app_spacing.dart';
import 'package:flutter_id_card/shared/theme/app_typography.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_controls.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_scaffold.dart';
import 'package:flutter_id_card/shared/widgets/glass/glass_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen 18 — connected to a school, waiting for a class.
///
/// This screen exists because the alternative is a greyed-out home screen,
/// and a teacher who lands on one of those rings the office to ask whether
/// the app is broken. Naming the state, and naming who resolves it, removes
/// that call. It is the cheapest screen in the project and probably the one
/// that saves the most time.
///
/// It is deliberately not styled as an error. Waiting here is the system
/// working exactly as designed.
class AwaitingAssignmentScreen extends ConsumerStatefulWidget {
  const AwaitingAssignmentScreen({super.key});

  static const String routePath = '/join/waiting';
  static const String routeName = 'join-waiting';

  @override
  ConsumerState<AwaitingAssignmentScreen> createState() =>
      _AwaitingAssignmentScreenState();
}

class _AwaitingAssignmentScreenState
    extends ConsumerState<AwaitingAssignmentScreen> {
  bool _checking = false;

  /// Re-reads the user document on demand.
  ///
  /// The stream below already moves this screen on by itself when the office
  /// acts. The button stays because a teacher who has been waiting wants
  /// something to press, and a screen with no controls reads as frozen even
  /// when it is working. Pressing it when nothing has changed is meant to be
  /// harmless and visibly so.
  Future<void> _checkAgain() async {
    final SessionUser? session = ref.read(currentSessionProvider);
    if (session == null) return;

    setState(() => _checking = true);
    final JoinState state = await ref
        .read(joinRepositoryProvider)
        .currentState(session.uid);
    if (!mounted) return;
    setState(() => _checking = false);

    if (state.schoolId.isNotEmpty && state.status == JoinStatus.active) {
      context.go(HomeScreen.routePath);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Still waiting for the office to assign your class.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<JoinState> joinState = ref.watch(joinStateProvider);
    final SessionUser? session = ref.watch(currentSessionProvider);

    // The office acting moves the teacher on without them touching anything.
    ref.listen<AsyncValue<JoinState>>(joinStateProvider, (
      AsyncValue<JoinState>? _,
      AsyncValue<JoinState> next,
    ) {
      final JoinState? value = next.value;
      if (value == null) return;
      if (value.schoolId.isNotEmpty && value.status == JoinStatus.active) {
        context.go(HomeScreen.routePath);
      }
    });

    final String schoolName = joinState.value?.schoolName ?? '';

    return GlassScaffold(
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
                const FadeSlideIn(child: _WaitingBadge()),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  index: 1,
                  child: Column(
                    children: <Widget>[
                      const Text('Connected to', style: AppTypography.support),
                      const SizedBox(height: 4),
                      Text(
                        schoolName.isEmpty ? 'your school' : schoolName,
                        textAlign: TextAlign.center,
                        style: AppTypography.display.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  index: 2,
                  child: Text(
                    'Your class and section have not been assigned yet.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(height: 26),
                const FadeSlideIn(index: 3, child: _WhatHappensNext()),
                const SizedBox(height: 26),
                FadeSlideIn(
                  index: 4,
                  child: GlassButton(
                    label: 'Check again',
                    icon: Icons.refresh,
                    busy: _checking,
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.chatAccent, AppColors.chatDeep],
                    ),
                    onPressed: _checking
                        ? null
                        : () => unawaited(_checkAgain()),
                  ),
                ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  index: 5,
                  child: TextButton(
                    onPressed: () => unawaited(
                      ref.read(authControllerProvider.notifier).signOut(),
                    ),
                    child: Text(
                      'Sign out',
                      style: AppTypography.badge.copyWith(
                        fontSize: 14,
                        color: AppColors.chatDeep,
                      ),
                    ),
                  ),
                ),
                if (session != null && session.email.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  // So a teacher asking the office to find them can say which
                  // account to look for.
                  Text(
                    'Waiting as ${session.email}',
                    style: AppTypography.support.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Waiting, not failing. Amber rather than red, and an hourglass rather than a
/// warning triangle: this state is the system working as designed, and error
/// language would send a teacher to the office to report a fault that does not
/// exist.
class _WaitingBadge extends StatelessWidget {
  const _WaitingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.pendingTint,
        border: Border.all(
          color: AppColors.pending.withValues(alpha: 0.26),
          width: 1.4,
        ),
        boxShadow: AppShadows.subtle,
      ),
      child: const Icon(
        Icons.hourglass_empty,
        color: AppColors.pending,
        size: 40,
      ),
    );
  }
}

/// The three steps, named.
///
/// Telling a teacher what happens next and who does it is the difference
/// between waiting and being stuck.
class _WhatHappensNext extends StatelessWidget {
  const _WhatHappensNext();

  static const List<String> _steps = <String>[
    'Your school office sees your name in their pending list.',
    'They assign you a class and section, for example Class 10 - A.',
    'You can then capture student photos and send ID card details.',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.panelR,
      fill: AppColors.glassFillStrong,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('What happens next', style: AppTypography.section),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _steps.length - 1 ? 0 : AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.chatAccent,
                          AppColors.chatDeep,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.buttonSmall.copyWith(fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: AppTypography.body.copyWith(
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
