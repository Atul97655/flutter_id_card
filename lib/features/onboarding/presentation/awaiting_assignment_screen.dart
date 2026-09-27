import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/data_entry/presentation/home_screen.dart';
import 'package:flutter_id_card/features/onboarding/application/join_providers.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_id_card/shared/theme/app_motion.dart';
import 'package:flutter_id_card/shared/theme/join_theme.dart';
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
                  const FadeSlideIn(child: _WaitingBadge()),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 1,
                    child: Column(
                      children: <Widget>[
                        Text(
                          'Connected to',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          schoolName.isEmpty ? 'your school' : schoolName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const FadeSlideIn(
                    index: 2,
                    child: Text(
                      'Your class and section have not been assigned yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const FadeSlideIn(index: 3, child: _WhatHappensNext()),
                  const SizedBox(height: 26),
                  FadeSlideIn(
                    index: 4,
                    child: FilledButton(
                      style: JoinTheme.filledButton(),
                      onPressed: _checking
                          ? null
                          : () => unawaited(_checkAgain()),
                      child: _checking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Check again'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    index: 5,
                    child: TextButton(
                      onPressed: () => unawaited(
                        ref.read(authControllerProvider.notifier).signOut(),
                      ),
                      child: const Text('Sign out'),
                    ),
                  ),
                  if (session != null && session.email.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    // So a teacher asking the office to find them can say
                    // which account to look for.
                    Text(
                      'Waiting as ${session.email}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  const _WaitingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(
        color: JoinTheme.waitingSoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.hourglass_empty,
        color: Color(0xFF9A7B16),
        size: 36,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'What happens next',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: JoinTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: const TextStyle(fontSize: 13, height: 1.45),
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
