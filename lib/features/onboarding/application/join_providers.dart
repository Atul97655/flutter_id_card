import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/onboarding/data/join_repository.dart';
import 'package:flutter_id_card/features/onboarding/domain/join_models.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<JoinRepository> joinRepositoryProvider =
    Provider<JoinRepository>(
      (Ref ref) => JoinRepository(FirebaseFirestore.instance),
    );

/// Where the signed-in teacher stands with their school.
///
/// Emits [JoinState.none] rather than an error when Firebase is unavailable
/// or nobody is signed in. Both are ordinary situations - an offline test
/// session is one of them - and a red error box on the onboarding screen
/// would be the first thing a new teacher ever saw.
final StreamProvider<JoinState> joinStateProvider = StreamProvider<JoinState>((
  Ref ref,
) {
  final SessionUser? session = ref.watch(currentSessionProvider);

  if (session == null ||
      session.isOfflineTestSession ||
      !FirebaseBootstrap.instance.isReady) {
    return Stream<JoinState>.value(JoinState.none);
  }

  return ref.watch(joinRepositoryProvider).watchState(session.uid);
});

/// The teacher's section, or empty when they are not scoped to one.
///
/// Empty is the answer for every account that existed before sections, and
/// the home screen reads it as "show everything" rather than "show nothing" -
/// matching the rules, which narrow nobody who has not been given a section.
final Provider<String> mySectionLabelProvider = Provider<String>(
  (Ref ref) => ref.watch(joinStateProvider).value?.sectionLabel ?? '',
);
