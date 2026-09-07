import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/services/local/print_batch_repository.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:intl/intl.dart';

/// Per-school report summarizing student submission and approval counts.
class SchoolReportItem {
  const SchoolReportItem({
    required this.schoolId,
    required this.schoolName,
    required this.cardSizeLabel,
    required this.totalCount,
    required this.approvedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.printableCount,
  });

  final String schoolId;
  final String schoolName;
  final String cardSizeLabel;
  final int totalCount;
  final int approvedCount;
  final int pendingCount;
  final int rejectedCount;
  final int printableCount;

  double get approvalPercentage =>
      totalCount > 0 ? (approvedCount / totalCount * 100) : 0.0;
}

/// Monthly volume breakdown of student registrations.
class MonthlySummaryItem {
  const MonthlySummaryItem({
    required this.yearMonth,
    required this.label,
    required this.count,
  });

  final String yearMonth;
  final String label;
  final int count;
}

/// Top-level system analytics report across all schools.
class SystemReport {
  const SystemReport({
    required this.totalSchools,
    required this.totalStudents,
    required this.totalApproved,
    required this.totalPending,
    required this.totalRejected,
    required this.totalPrintable,
    required this.totalBatches,
    required this.totalCardsPrinted,
    required this.schoolReports,
    required this.monthlyTrend,
  });

  final int totalSchools;
  final int totalStudents;
  final int totalApproved;
  final int totalPending;
  final int totalRejected;
  final int totalPrintable;
  final int totalBatches;
  final int totalCardsPrinted;
  final List<SchoolReportItem> schoolReports;
  final List<MonthlySummaryItem> monthlyTrend;

  double get overallApprovalPercentage =>
      totalStudents > 0 ? (totalApproved / totalStudents * 100) : 0.0;
}

/// Aggregates database rows into actionable management reports.
class ReportsService {
  const ReportsService({
    required this.students,
    required this.schools,
    required this.printBatches,
  });

  final StudentRepository students;
  final SchoolRepository schools;
  final PrintBatchRepository printBatches;

  static final DateFormat _monthFmt = DateFormat('MMM yyyy');

  /// Compiles a complete [SystemReport] by cross-referencing schools,
  /// students, and print batches.
  Future<SystemReport> generateReport() async {
    final List<SchoolConfig> allSchools = await schools.listAll();
    final List<PrintBatch> allBatches = await printBatches.watchAll().first;

    final List<SchoolReportItem> schoolReports = <SchoolReportItem>[];
    int totalStudents = 0;
    int totalApproved = 0;
    int totalPending = 0;
    int totalRejected = 0;
    int totalPrintable = 0;

    final Map<String, int> monthlyCounts = <String, int>{};
    final Map<String, String> monthLabels = <String, String>{};

    for (final SchoolConfig school in allSchools) {
      final List<StudentEntry> entries =
          await students.listBySchool(school.id);

      int approved = 0;
      int pending = 0;
      int rejected = 0;
      int printable = 0;

      for (final StudentEntry e in entries) {
        if (e.approvalStatus == ApprovalStatus.approved) {
          approved++;
          if (e.hasPhoto) printable++;
        } else if (e.approvalStatus == ApprovalStatus.rejected) {
          rejected++;
        } else {
          pending++;
        }

        // Tally monthly submission trends
        final String ym =
            '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}';
        monthlyCounts[ym] = (monthlyCounts[ym] ?? 0) + 1;
        monthLabels.putIfAbsent(ym, () => _monthFmt.format(e.createdAt));
      }

      totalStudents += entries.length;
      totalApproved += approved;
      totalPending += pending;
      totalRejected += rejected;
      totalPrintable += printable;

      schoolReports.add(
        SchoolReportItem(
          schoolId: school.id,
          schoolName: school.name,
          cardSizeLabel: school.cardSize.label,
          totalCount: entries.length,
          approvedCount: approved,
          pendingCount: pending,
          rejectedCount: rejected,
          printableCount: printable,
        ),
      );
    }

    // Sort school reports by student count descending
    schoolReports.sort(
        (SchoolReportItem a, SchoolReportItem b) => b.totalCount.compareTo(a.totalCount));

    // Sort monthly trend chronologically
    final List<String> sortedMonths = monthlyCounts.keys.toList()..sort();
    final List<MonthlySummaryItem> monthlyTrend = sortedMonths
        .map(
          (String ym) => MonthlySummaryItem(
            yearMonth: ym,
            label: monthLabels[ym] ?? ym,
            count: monthlyCounts[ym] ?? 0,
          ),
        )
        .toList();

    int totalCardsPrinted = 0;
    for (final PrintBatch b in allBatches) {
      totalCardsPrinted += b.cardCount;
    }

    return SystemReport(
      totalSchools: allSchools.length,
      totalStudents: totalStudents,
      totalApproved: totalApproved,
      totalPending: totalPending,
      totalRejected: totalRejected,
      totalPrintable: totalPrintable,
      totalBatches: allBatches.length,
      totalCardsPrinted: totalCardsPrinted,
      schoolReports: schoolReports,
      monthlyTrend: monthlyTrend,
    );
  }
}
