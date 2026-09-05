import 'package:flutter_id_card/features/admin/data/export_service.dart';
import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<ExportService> exportServiceProvider =
    Provider<ExportService>((Ref ref) => ExportService());

/// Every school the admin can manage.
final StreamProvider<List<SchoolConfig>> allSchoolsProvider =
    StreamProvider<List<SchoolConfig>>((Ref ref) {
  final SchoolRepository repo = ref.watch(schoolRepositoryProvider);
  return repo.watchAll();
});

/// Every entry across all schools - the source the dashboard counts from.
final StreamProvider<List<StudentEntry>> allEntriesProvider =
    StreamProvider<List<StudentEntry>>((Ref ref) {
  final StudentRepository repo = ref.watch(studentRepositoryProvider);
  return repo.watchAll();
});

/// Entries for one school, for the submissions screen.
final entriesForSchoolProvider =
    StreamProvider.family<List<StudentEntry>, String>((Ref ref, String schoolId) {
  final StudentRepository repo = ref.watch(studentRepositoryProvider);
  return repo.watchBySchool(schoolId);
});

/// One school's settings, for the settings screen.
final schoolByIdProvider =
    StreamProvider.family<SchoolConfig?, String>((Ref ref, String schoolId) {
  final SchoolRepository repo = ref.watch(schoolRepositoryProvider);
  return repo.watch(schoolId);
});

/// Headline counts for the dashboard.
class AdminStats {
  const AdminStats({
    this.schools = 0,
    this.total = 0,
    this.awaitingReview = 0,
    this.approved = 0,
    this.rejected = 0,
    this.printable = 0,
  });

  final int schools;
  final int total;
  final int awaitingReview;
  final int approved;
  final int rejected;

  /// Approved *and* carrying a photo - what can actually go on a sheet. Kept
  /// distinct from [approved] because an approved entry whose photo went
  /// missing would otherwise inflate the number an admin plans a print run
  /// against.
  final int printable;
}

final Provider<AsyncValue<AdminStats>> adminStatsProvider =
    Provider<AsyncValue<AdminStats>>((Ref ref) {
  final AsyncValue<List<StudentEntry>> entries = ref.watch(allEntriesProvider);
  final AsyncValue<List<SchoolConfig>> schools = ref.watch(allSchoolsProvider);

  return entries.whenData((List<StudentEntry> all) {
    int awaiting = 0;
    int approved = 0;
    int rejected = 0;
    int printable = 0;

    for (final StudentEntry e in all) {
      switch (e.approvalStatus) {
        case ApprovalStatus.pending:
          awaiting++;
        case ApprovalStatus.approved:
          approved++;
          if (e.hasPhoto) printable++;
        case ApprovalStatus.rejected:
          rejected++;
      }
    }

    return AdminStats(
      schools: schools.value?.length ?? 0,
      total: all.length,
      awaitingReview: awaiting,
      approved: approved,
      rejected: rejected,
      printable: printable,
    );
  });
});
