import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live settings for the school currently being worked on.
///
/// Falls back to an all-fields-enabled default when nothing has synced yet, so
/// a brand-new device can still take entries on its first day. The fallback is
/// deliberately permissive: hiding fields an operator was told to fill in is
/// worse than showing one they can leave blank.
final StreamProvider<SchoolConfig> schoolConfigProvider =
    StreamProvider<SchoolConfig>((Ref ref) {
  final String? schoolId = ref.watch(activeSchoolIdProvider);
  if (schoolId == null || schoolId.isEmpty) {
    return Stream<SchoolConfig>.value(SchoolConfig.fallback('unknown'));
  }
  final SchoolRepository repo = ref.watch(schoolRepositoryProvider);
  return repo.watch(schoolId).map(
        (SchoolConfig? config) => config ??
            SchoolConfig.fallback(schoolId).copyWith(
              enabledFieldKeys: SchoolConfig.allFieldKeys,
            ),
      );
});

/// All saved entries for the active school, newest first.
final StreamProvider<List<StudentEntry>> entriesProvider =
    StreamProvider<List<StudentEntry>>((Ref ref) {
  final String? schoolId = ref.watch(activeSchoolIdProvider);
  if (schoolId == null || schoolId.isEmpty) {
    return Stream<List<StudentEntry>>.value(const <StudentEntry>[]);
  }
  final StudentRepository repo = ref.watch(studentRepositoryProvider);
  return repo.watchBySchool(schoolId);
});

/// Per-status tallies for the home screen badges and the Sync Status screen.
final Provider<AsyncValue<Map<SyncStatus, int>>> syncCountsProvider =
    Provider<AsyncValue<Map<SyncStatus, int>>>((Ref ref) {
  return ref.watch(entriesProvider).whenData((List<StudentEntry> entries) {
    final Map<SyncStatus, int> counts = <SyncStatus, int>{
      for (final SyncStatus s in SyncStatus.values) s: 0,
    };
    for (final StudentEntry e in entries) {
      counts[e.syncStatus] = (counts[e.syncStatus] ?? 0) + 1;
    }
    return counts;
  });
});

/// Per-approval-state tallies for the My Submissions filter tabs.
///
/// Separate from [syncCountsProvider]: that one answers "has this reached the
/// server?", this one answers "what did the office decide?". A teacher cares
/// about the second and only notices the first when something is stuck.
final Provider<AsyncValue<Map<ApprovalStatus, int>>> submissionCountsProvider =
    Provider<AsyncValue<Map<ApprovalStatus, int>>>((Ref ref) {
  return ref.watch(entriesProvider).whenData((List<StudentEntry> entries) {
    final Map<ApprovalStatus, int> counts = <ApprovalStatus, int>{
      for (final ApprovalStatus s in ApprovalStatus.values) s: 0,
    };
    for (final StudentEntry e in entries) {
      counts[e.approvalStatus] = (counts[e.approvalStatus] ?? 0) + 1;
    }
    return counts;
  });
});

/// Entries the operator needs to do something about - rejected work, which is
/// the only state that is genuinely their move. Drives the home screen badge.
final Provider<List<StudentEntry>> needsAttentionProvider =
    Provider<List<StudentEntry>>((Ref ref) {
  final List<StudentEntry> all =
      ref.watch(entriesProvider).value ?? const <StudentEntry>[];
  return all
      .where((StudentEntry e) => e.approvalStatus.needsOperatorAttention)
      .toList();
});

/// Entries holding a photo the office does not have.
///
/// Worth showing on its own rather than folding into the failed-upload count,
/// because it is a different problem with a different remedy: the student's
/// record IS at the office and nothing needs re-entering - only the picture is
/// outstanding. Telling an operator "upload failed" for this state sends them
/// to retake a photo that was never wrong.
///
/// It is also the readout that answers "why is this card still not printable",
/// which without it is only answerable with a debugger.
final Provider<List<StudentEntry>> photosAwaitingUploadProvider =
    Provider<List<StudentEntry>>((Ref ref) {
      final List<StudentEntry> all =
          ref.watch(entriesProvider).value ?? const <StudentEntry>[];
      return all
          .where(
            (StudentEntry e) =>
                (e.localPhotoPath?.isNotEmpty ?? false) &&
                !e.photoReachedServer,
          )
          .toList();
    });

/// A single entry by id, for the edit and preview flows.
///
/// Derived from [entriesProvider] rather than issuing its own query, so the
/// preview screen updates the moment the underlying row changes.
// Type is inferred: Riverpod 3's family provider classes are not part of its
// public API surface, so there is nothing stable to annotate with here.
final entryByIdProvider = Provider.family<StudentEntry?, String>((Ref ref, String id) {
  final List<StudentEntry> entries =
      ref.watch(entriesProvider).value ?? const <StudentEntry>[];
  for (final StudentEntry e in entries) {
    if (e.id == id) return e;
  }
  return null;
});
