import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/firebase/seen_marker_service.dart';
import 'package:flutter_id_card/shared/services/local/app_flag_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<SeenMarkerService> seenMarkerServiceProvider =
    Provider<SeenMarkerService>(
      (Ref ref) =>
          SeenMarkerService(flags: ref.watch(appFlagRepositoryProvider)),
    );

/// Which notifications this operator has already looked at.
///
/// Watched rather than read so the badge clears in the same frame the
/// notifications screen writes the set, without anything having to tell it to.
final StreamProvider<Set<String>> notificationsSeenIdsProvider =
    StreamProvider<Set<String>>((Ref ref) {
      return ref
          .watch(appFlagRepositoryProvider)
          .watchStringSet(AppFlagRepository.notificationsSeenIdsKey);
    });

/// Which returned cards the operator has dismissed the Profile banner for.
final StreamProvider<Set<String>> returnedDismissedIdsProvider =
    StreamProvider<Set<String>>((Ref ref) {
      return ref
          .watch(appFlagRepositoryProvider)
          .watchStringSet(AppFlagRepository.returnedDismissedIdsKey);
    });

/// Pulls the account's seen sets down once per signed-in session.
///
/// Watched at the app root next to the sync worker. It has to run before the
/// first badge is drawn on a fresh install, which is the whole case it
/// exists for: without it, reinstalling the app re-announces every approval
/// and every returned card the operator had already dealt with.
final FutureProvider<void> seenMarkerPullProvider = FutureProvider<void>((
  Ref ref,
) async {
  final SessionUser? session = ref.watch(currentSessionProvider);
  if (session == null || session.isOfflineTestSession) return;
  await ref.watch(seenMarkerServiceProvider).pullFor(session.uid);
});
