/// Where a submitted entry sits in the admin's review queue.
///
/// Deliberately separate from `SyncStatus`. The two answer different questions
/// and move independently:
///
///   SyncStatus     - "has this record reached the server yet?"  (device -> cloud)
///   ApprovalStatus - "has a human signed off on printing it?"   (admin decision)
///
/// An entry can be `synced` but still `pending` review, and an operator must be
/// able to see both at once. Collapsing them into one enum would make
/// "uploaded but not yet approved" indistinguishable from "not uploaded".
///
/// Only [approved] entries are eligible for the print run - see
/// `ApprovalStatus.isPrintable`.
enum ApprovalStatus {
  /// Submitted, waiting for an admin to review it. The default for every new
  /// entry.
  pending('Pending review'),

  /// An admin has signed off. The entry can go into a print batch.
  approved('Approved'),

  /// An admin sent it back. `StudentEntry.rejectionReason` carries the why, so
  /// the operator can fix the specific problem rather than guessing.
  rejected('Rejected');

  const ApprovalStatus(this.label);

  final String label;

  /// Only approved work reaches a printer. This is the single gate the
  /// imposition and export paths check.
  bool get isPrintable => this == ApprovalStatus.approved;

  /// Whether the operator is expected to act on this entry.
  bool get needsOperatorAttention => this == ApprovalStatus.rejected;

  /// Whether it is still sitting in the admin's queue.
  bool get awaitsReview => this == ApprovalStatus.pending;

  /// Unknown values fall back to [pending] rather than throwing: a status
  /// written by a newer admin build must not brick an older operator build,
  /// and "needs review" is the safe default - it can never cause something
  /// unapproved to be printed.
  static ApprovalStatus fromName(String? value) =>
      ApprovalStatus.values.firstWhere(
        (ApprovalStatus s) => s.name == value,
        orElse: () => ApprovalStatus.pending,
      );
}
