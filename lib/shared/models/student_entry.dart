import 'package:flutter_id_card/shared/models/approval_status.dart';
import 'package:flutter_id_card/shared/models/student_field.dart';
import 'package:flutter_id_card/shared/models/sync_status.dart';
import 'package:intl/intl.dart';

/// One student's card data.
///
/// This is the domain model. It is deliberately independent of both Drift and
/// Firestore so the storage layer can change without touching the renderer or
/// the form. Mapping lives in the repository, except for the Firestore map
/// helpers below which are shared by the sync service and the admin panel.
class StudentEntry {
  const StudentEntry({
    required this.id,
    required this.schoolId,
    this.name = '',
    this.fatherName = '',
    this.studentClass = '',
    this.division = '',
    this.rollNumber = '',
    this.bloodGroup = '',
    this.dob,
    this.mobile = '',
    this.address = '',
    this.localPhotoPath,
    this.remotePhotoUrl,
    this.syncStatus = SyncStatus.pending,
    this.syncAttempts = 0,
    this.syncError,
    this.lastSyncAttemptAt,
    this.detailsSyncedAt,
    this.approvalStatus = ApprovalStatus.pending,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;

  final String name;
  final String fatherName;
  final String studentClass;
  final String division;

  /// The school's own register number for the student. Free text, not an int -
  /// real registers use values like `12/A` and `0034`, and a leading zero that
  /// an int would drop is meaningful to the school.
  final String rollNumber;

  final String bloodGroup;
  final DateTime? dob;
  final String mobile;
  final String address;

  /// Absolute path to the processed 360x450 photo on this device.
  final String? localPhotoPath;

  /// Firebase Storage download URL, set once the photo has uploaded.
  final String? remotePhotoUrl;

  final SyncStatus syncStatus;
  final int syncAttempts;
  final String? syncError;

  /// When the sync worker last tried to upload this row, or null if it never
  /// has. Distinct from [updatedAt], which is when the *operator* last edited
  /// it - the retry backoff and the stuck-upload sweep both need the former.
  ///
  /// Device-local bookkeeping: not part of [toFirestoreMap].
  final DateTime? lastSyncAttemptAt;

  /// When the student's DETAILS last reached Firestore, or null if they never
  /// have. A row can be `failed` with this set: the document landed and only
  /// the photo is outstanding, which is a very different thing to tell an
  /// operator than "upload failed".
  final DateTime? detailsSyncedAt;

  /// True once the office holds this student's record, whatever the photo is
  /// doing.
  bool get detailsReachedServer => detailsSyncedAt != null;

  /// The details are up but the photo is not - the state a missing Storage
  /// bucket produces for every submission.
  bool get awaitingPhotoUpload =>
      detailsReachedServer &&
      syncStatus != SyncStatus.synced &&
      (remotePhotoUrl == null || remotePhotoUrl!.isEmpty) &&
      (localPhotoPath?.isNotEmpty ?? false);

  /// The admin's review decision. Independent of [syncStatus] - see
  /// [ApprovalStatus] for why the two are kept apart.
  final ApprovalStatus approvalStatus;

  /// Set only when [approvalStatus] is rejected, so the operator is told the
  /// specific problem instead of just "rejected".
  final String? rejectionReason;

  /// Audit trail for the review decision.
  final String? reviewedBy;
  final DateTime? reviewedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// The gate the print pipeline checks. An entry must have been reviewed and
  /// approved before it can be placed on a sheet.
  bool get isPrintable => approvalStatus.isPrintable;

  /// Display/print format. The spec fixes this as DD-MM-YYYY; it is used by
  /// both the card renderer and the entry list, so it lives here.
  static final DateFormat dobFormat = DateFormat('dd-MM-yyyy');

  String get formattedDob => dob == null ? '' : dobFormat.format(dob!);

  bool get hasPhoto => (localPhotoPath?.isNotEmpty ?? false) || (remotePhotoUrl?.isNotEmpty ?? false);

  /// Reads a field generically. The card renderer walks the school's enabled
  /// field list and calls this, so adding a field to the layout never requires
  /// a switch statement in the drawing code.
  String valueOf(StudentField field) => switch (field) {
        StudentField.name => name,
        StudentField.fatherName => fatherName,
        StudentField.studentClass => studentClass,
        StudentField.division => division,
        StudentField.rollNumber => rollNumber,
        StudentField.bloodGroup => bloodGroup,
        StudentField.dob => formattedDob,
        StudentField.mobile => mobile,
        StudentField.address => address,
        StudentField.photo => localPhotoPath ?? remotePhotoUrl ?? '',
      };

  /// Filename-safe identifier used for single-card PDF exports:
  /// `STUDENTNAME_CLASS.pdf`.
  String get exportBaseName {
    final String rawName = name.trim().isEmpty ? 'UNNAMED' : name.trim();
    final String rawClass = studentClass.trim();
    final String combined = rawClass.isEmpty ? rawName : '${rawName}_$rawClass';
    // Strip anything Windows or POSIX would reject in a filename.
    return combined
        .toUpperCase()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(' ', '_');
  }

  StudentEntry copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? fatherName,
    String? studentClass,
    String? division,
    String? rollNumber,
    String? bloodGroup,
    DateTime? dob,
    bool clearDob = false,
    String? mobile,
    String? address,
    String? localPhotoPath,
    bool clearLocalPhotoPath = false,
    String? remotePhotoUrl,
    SyncStatus? syncStatus,
    int? syncAttempts,
    String? syncError,
    bool clearSyncError = false,
    DateTime? lastSyncAttemptAt,
    DateTime? detailsSyncedAt,
    ApprovalStatus? approvalStatus,
    String? rejectionReason,
    bool clearRejectionReason = false,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentEntry(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      studentClass: studentClass ?? this.studentClass,
      division: division ?? this.division,
      rollNumber: rollNumber ?? this.rollNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dob: clearDob ? null : (dob ?? this.dob),
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      localPhotoPath: clearLocalPhotoPath ? null : (localPhotoPath ?? this.localPhotoPath),
      remotePhotoUrl: remotePhotoUrl ?? this.remotePhotoUrl,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      detailsSyncedAt: detailsSyncedAt ?? this.detailsSyncedAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason:
          clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore representation. `dob` is stored as an ISO date-only string
  /// rather than a Timestamp so that a card printed in one timezone can never
  /// show a different birth date than the one that was typed.
  Map<String, Object?> toFirestoreMap() => <String, Object?>{
        'schoolId': schoolId,
        'name': name,
        'fatherName': fatherName,
        'studentClass': studentClass,
        'division': division,
        'rollNumber': rollNumber,
        'bloodGroup': bloodGroup,
        'dob': dob == null ? null : DateFormat('yyyy-MM-dd').format(dob!),
        'mobile': mobile,
        'address': address,
        'photoUrl': remotePhotoUrl,
        'approvalStatus': approvalStatus.name,
        'rejectionReason': rejectionReason,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static StudentEntry fromFirestoreMap(String id, Map<String, Object?> map) {
    return StudentEntry(
      id: id,
      schoolId: (map['schoolId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      fatherName: (map['fatherName'] as String?) ?? '',
      studentClass: (map['studentClass'] as String?) ?? '',
      division: (map['division'] as String?) ?? '',
      rollNumber: (map['rollNumber'] as String?) ?? '',
      bloodGroup: (map['bloodGroup'] as String?) ?? '',
      dob: _parseDate(map['dob'] as String?),
      mobile: (map['mobile'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      remotePhotoUrl: map['photoUrl'] as String?,
      syncStatus: SyncStatus.synced,
      approvalStatus: ApprovalStatus.fromName(map['approvalStatus'] as String?),
      rejectionReason: map['rejectionReason'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: _parseDate(map['reviewedAt'] as String?),
      createdAt: _parseDate(map['createdAt'] as String?) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt'] as String?) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  String toString() => 'StudentEntry($id, $name, ${syncStatus.name})';
}
