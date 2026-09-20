import 'dart:async';

import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/firebase/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single sync worker for the process.
final Provider<SyncService> syncServiceProvider = Provider<SyncService>((
  Ref ref,
) {
  final SyncService service = SyncService(
    students: ref.watch(studentRepositoryProvider),
    schools: ref.watch(schoolRepositoryProvider),
    auditRepo: ref.watch(auditRepositoryProvider),
    flags: ref.watch(appFlagRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Starts and stops the worker in step with the session.
///
/// Watching the session rather than starting it in `main` matters for two
/// reasons: there is nothing to sync before anyone signs in, and an offline
/// debug session must never upload test data to the production project.
final Provider<void> syncLifecycleProvider = Provider<void>((Ref ref) {
  final SessionUser? session = ref.watch(currentSessionProvider);
  final SyncService service = ref.watch(syncServiceProvider);

  if (session == null || session.isOfflineTestSession) {
    unawaited(service.stop());
    return;
  }

  final String? schoolId = session.schoolId;

  // An admin has no schoolId - they sync every school instead of one, which is
  // what fills the dashboard and review queue.
  if (!session.isAdmin && (schoolId == null || schoolId.isEmpty)) {
    unawaited(service.stop());
    return;
  }

  unawaited(service.start(schoolId: schoolId, isAdmin: session.isAdmin));
  ref.onDispose(() => unawaited(service.stop()));
});

/// Live sync state for the UI. Seeded with the service's current value so a
/// screen opened between passes shows the last known state rather than blank.
final StreamProvider<SyncState> syncStateProvider = StreamProvider<SyncState>((
  Ref ref,
) {
  final SyncService service = ref.watch(syncServiceProvider);
  return service.stateStream;
});

void unawaited(Future<void> future) => future.ignore();
