// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StudentEntriesTable extends StudentEntries
    with TableInfo<$StudentEntriesTable, StudentEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fatherNameMeta = const VerificationMeta(
    'fatherName',
  );
  @override
  late final GeneratedColumn<String> fatherName = GeneratedColumn<String>(
    'father_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _studentClassMeta = const VerificationMeta(
    'studentClass',
  );
  @override
  late final GeneratedColumn<String> studentClass = GeneratedColumn<String>(
    'student_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _divisionMeta = const VerificationMeta(
    'division',
  );
  @override
  late final GeneratedColumn<String> division = GeneratedColumn<String>(
    'division',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bloodGroupMeta = const VerificationMeta(
    'bloodGroup',
  );
  @override
  late final GeneratedColumn<String> bloodGroup = GeneratedColumn<String>(
    'blood_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dobMeta = const VerificationMeta('dob');
  @override
  late final GeneratedColumn<DateTime> dob = GeneratedColumn<DateTime>(
    'dob',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mobileMeta = const VerificationMeta('mobile');
  @override
  late final GeneratedColumn<String> mobile = GeneratedColumn<String>(
    'mobile',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localPhotoPathMeta = const VerificationMeta(
    'localPhotoPath',
  );
  @override
  late final GeneratedColumn<String> localPhotoPath = GeneratedColumn<String>(
    'local_photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remotePhotoUrlMeta = const VerificationMeta(
    'remotePhotoUrl',
  );
  @override
  late final GeneratedColumn<String> remotePhotoUrl = GeneratedColumn<String>(
    'remote_photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncAttemptsMeta = const VerificationMeta(
    'syncAttempts',
  );
  @override
  late final GeneratedColumn<int> syncAttempts = GeneratedColumn<int>(
    'sync_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approvalStatusMeta = const VerificationMeta(
    'approvalStatus',
  );
  @override
  late final GeneratedColumn<String> approvalStatus = GeneratedColumn<String>(
    'approval_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _rejectionReasonMeta = const VerificationMeta(
    'rejectionReason',
  );
  @override
  late final GeneratedColumn<String> rejectionReason = GeneratedColumn<String>(
    'rejection_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewedByMeta = const VerificationMeta(
    'reviewedBy',
  );
  @override
  late final GeneratedColumn<String> reviewedBy = GeneratedColumn<String>(
    'reviewed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schoolId,
    name,
    fatherName,
    studentClass,
    division,
    bloodGroup,
    dob,
    mobile,
    address,
    localPhotoPath,
    remotePhotoUrl,
    syncStatus,
    syncAttempts,
    syncError,
    approvalStatus,
    rejectionReason,
    reviewedBy,
    reviewedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'student_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudentEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('father_name')) {
      context.handle(
        _fatherNameMeta,
        fatherName.isAcceptableOrUnknown(data['father_name']!, _fatherNameMeta),
      );
    }
    if (data.containsKey('student_class')) {
      context.handle(
        _studentClassMeta,
        studentClass.isAcceptableOrUnknown(
          data['student_class']!,
          _studentClassMeta,
        ),
      );
    }
    if (data.containsKey('division')) {
      context.handle(
        _divisionMeta,
        division.isAcceptableOrUnknown(data['division']!, _divisionMeta),
      );
    }
    if (data.containsKey('blood_group')) {
      context.handle(
        _bloodGroupMeta,
        bloodGroup.isAcceptableOrUnknown(data['blood_group']!, _bloodGroupMeta),
      );
    }
    if (data.containsKey('dob')) {
      context.handle(
        _dobMeta,
        dob.isAcceptableOrUnknown(data['dob']!, _dobMeta),
      );
    }
    if (data.containsKey('mobile')) {
      context.handle(
        _mobileMeta,
        mobile.isAcceptableOrUnknown(data['mobile']!, _mobileMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('local_photo_path')) {
      context.handle(
        _localPhotoPathMeta,
        localPhotoPath.isAcceptableOrUnknown(
          data['local_photo_path']!,
          _localPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('remote_photo_url')) {
      context.handle(
        _remotePhotoUrlMeta,
        remotePhotoUrl.isAcceptableOrUnknown(
          data['remote_photo_url']!,
          _remotePhotoUrlMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_attempts')) {
      context.handle(
        _syncAttemptsMeta,
        syncAttempts.isAcceptableOrUnknown(
          data['sync_attempts']!,
          _syncAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('approval_status')) {
      context.handle(
        _approvalStatusMeta,
        approvalStatus.isAcceptableOrUnknown(
          data['approval_status']!,
          _approvalStatusMeta,
        ),
      );
    }
    if (data.containsKey('rejection_reason')) {
      context.handle(
        _rejectionReasonMeta,
        rejectionReason.isAcceptableOrUnknown(
          data['rejection_reason']!,
          _rejectionReasonMeta,
        ),
      );
    }
    if (data.containsKey('reviewed_by')) {
      context.handle(
        _reviewedByMeta,
        reviewedBy.isAcceptableOrUnknown(data['reviewed_by']!, _reviewedByMeta),
      );
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudentEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      fatherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}father_name'],
      )!,
      studentClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_class'],
      )!,
      division: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}division'],
      )!,
      bloodGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blood_group'],
      )!,
      dob: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dob'],
      ),
      mobile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mobile'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      localPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_photo_path'],
      ),
      remotePhotoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_photo_url'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_attempts'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      approvalStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_status'],
      )!,
      rejectionReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rejection_reason'],
      ),
      reviewedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_by'],
      ),
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StudentEntriesTable createAlias(String alias) {
    return $StudentEntriesTable(attachedDatabase, alias);
  }
}

class StudentEntryRow extends DataClass implements Insertable<StudentEntryRow> {
  final String id;
  final String schoolId;
  final String name;
  final String fatherName;
  final String studentClass;
  final String division;
  final String bloodGroup;
  final DateTime? dob;
  final String mobile;
  final String address;
  final String? localPhotoPath;
  final String? remotePhotoUrl;

  /// Stores the `SyncStatus` enum name. Kept as text rather than an int so a
  /// database dump is readable during a support call.
  final String syncStatus;
  final int syncAttempts;
  final String? syncError;

  /// Stores the `ApprovalStatus` enum name - the admin's review decision,
  /// independent of whether the row has uploaded yet.
  final String approvalStatus;

  /// Why an admin rejected it. Null unless approvalStatus == 'rejected'.
  final String? rejectionReason;

  /// Auth UID of the admin who approved or rejected, and when. Kept as an
  /// audit trail - "who let this print?" is the first question asked when a
  /// wrong card reaches a school.
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StudentEntryRow({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.fatherName,
    required this.studentClass,
    required this.division,
    required this.bloodGroup,
    this.dob,
    required this.mobile,
    required this.address,
    this.localPhotoPath,
    this.remotePhotoUrl,
    required this.syncStatus,
    required this.syncAttempts,
    this.syncError,
    required this.approvalStatus,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['school_id'] = Variable<String>(schoolId);
    map['name'] = Variable<String>(name);
    map['father_name'] = Variable<String>(fatherName);
    map['student_class'] = Variable<String>(studentClass);
    map['division'] = Variable<String>(division);
    map['blood_group'] = Variable<String>(bloodGroup);
    if (!nullToAbsent || dob != null) {
      map['dob'] = Variable<DateTime>(dob);
    }
    map['mobile'] = Variable<String>(mobile);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || localPhotoPath != null) {
      map['local_photo_path'] = Variable<String>(localPhotoPath);
    }
    if (!nullToAbsent || remotePhotoUrl != null) {
      map['remote_photo_url'] = Variable<String>(remotePhotoUrl);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_attempts'] = Variable<int>(syncAttempts);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['approval_status'] = Variable<String>(approvalStatus);
    if (!nullToAbsent || rejectionReason != null) {
      map['rejection_reason'] = Variable<String>(rejectionReason);
    }
    if (!nullToAbsent || reviewedBy != null) {
      map['reviewed_by'] = Variable<String>(reviewedBy);
    }
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudentEntriesCompanion toCompanion(bool nullToAbsent) {
    return StudentEntriesCompanion(
      id: Value(id),
      schoolId: Value(schoolId),
      name: Value(name),
      fatherName: Value(fatherName),
      studentClass: Value(studentClass),
      division: Value(division),
      bloodGroup: Value(bloodGroup),
      dob: dob == null && nullToAbsent ? const Value.absent() : Value(dob),
      mobile: Value(mobile),
      address: Value(address),
      localPhotoPath: localPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPhotoPath),
      remotePhotoUrl: remotePhotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remotePhotoUrl),
      syncStatus: Value(syncStatus),
      syncAttempts: Value(syncAttempts),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      approvalStatus: Value(approvalStatus),
      rejectionReason: rejectionReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectionReason),
      reviewedBy: reviewedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedBy),
      reviewedAt: reviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StudentEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentEntryRow(
      id: serializer.fromJson<String>(json['id']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      name: serializer.fromJson<String>(json['name']),
      fatherName: serializer.fromJson<String>(json['fatherName']),
      studentClass: serializer.fromJson<String>(json['studentClass']),
      division: serializer.fromJson<String>(json['division']),
      bloodGroup: serializer.fromJson<String>(json['bloodGroup']),
      dob: serializer.fromJson<DateTime?>(json['dob']),
      mobile: serializer.fromJson<String>(json['mobile']),
      address: serializer.fromJson<String>(json['address']),
      localPhotoPath: serializer.fromJson<String?>(json['localPhotoPath']),
      remotePhotoUrl: serializer.fromJson<String?>(json['remotePhotoUrl']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncAttempts: serializer.fromJson<int>(json['syncAttempts']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      approvalStatus: serializer.fromJson<String>(json['approvalStatus']),
      rejectionReason: serializer.fromJson<String?>(json['rejectionReason']),
      reviewedBy: serializer.fromJson<String?>(json['reviewedBy']),
      reviewedAt: serializer.fromJson<DateTime?>(json['reviewedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schoolId': serializer.toJson<String>(schoolId),
      'name': serializer.toJson<String>(name),
      'fatherName': serializer.toJson<String>(fatherName),
      'studentClass': serializer.toJson<String>(studentClass),
      'division': serializer.toJson<String>(division),
      'bloodGroup': serializer.toJson<String>(bloodGroup),
      'dob': serializer.toJson<DateTime?>(dob),
      'mobile': serializer.toJson<String>(mobile),
      'address': serializer.toJson<String>(address),
      'localPhotoPath': serializer.toJson<String?>(localPhotoPath),
      'remotePhotoUrl': serializer.toJson<String?>(remotePhotoUrl),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncAttempts': serializer.toJson<int>(syncAttempts),
      'syncError': serializer.toJson<String?>(syncError),
      'approvalStatus': serializer.toJson<String>(approvalStatus),
      'rejectionReason': serializer.toJson<String?>(rejectionReason),
      'reviewedBy': serializer.toJson<String?>(reviewedBy),
      'reviewedAt': serializer.toJson<DateTime?>(reviewedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StudentEntryRow copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? fatherName,
    String? studentClass,
    String? division,
    String? bloodGroup,
    Value<DateTime?> dob = const Value.absent(),
    String? mobile,
    String? address,
    Value<String?> localPhotoPath = const Value.absent(),
    Value<String?> remotePhotoUrl = const Value.absent(),
    String? syncStatus,
    int? syncAttempts,
    Value<String?> syncError = const Value.absent(),
    String? approvalStatus,
    Value<String?> rejectionReason = const Value.absent(),
    Value<String?> reviewedBy = const Value.absent(),
    Value<DateTime?> reviewedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StudentEntryRow(
    id: id ?? this.id,
    schoolId: schoolId ?? this.schoolId,
    name: name ?? this.name,
    fatherName: fatherName ?? this.fatherName,
    studentClass: studentClass ?? this.studentClass,
    division: division ?? this.division,
    bloodGroup: bloodGroup ?? this.bloodGroup,
    dob: dob.present ? dob.value : this.dob,
    mobile: mobile ?? this.mobile,
    address: address ?? this.address,
    localPhotoPath: localPhotoPath.present
        ? localPhotoPath.value
        : this.localPhotoPath,
    remotePhotoUrl: remotePhotoUrl.present
        ? remotePhotoUrl.value
        : this.remotePhotoUrl,
    syncStatus: syncStatus ?? this.syncStatus,
    syncAttempts: syncAttempts ?? this.syncAttempts,
    syncError: syncError.present ? syncError.value : this.syncError,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    rejectionReason: rejectionReason.present
        ? rejectionReason.value
        : this.rejectionReason,
    reviewedBy: reviewedBy.present ? reviewedBy.value : this.reviewedBy,
    reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StudentEntryRow copyWithCompanion(StudentEntriesCompanion data) {
    return StudentEntryRow(
      id: data.id.present ? data.id.value : this.id,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      name: data.name.present ? data.name.value : this.name,
      fatherName: data.fatherName.present
          ? data.fatherName.value
          : this.fatherName,
      studentClass: data.studentClass.present
          ? data.studentClass.value
          : this.studentClass,
      division: data.division.present ? data.division.value : this.division,
      bloodGroup: data.bloodGroup.present
          ? data.bloodGroup.value
          : this.bloodGroup,
      dob: data.dob.present ? data.dob.value : this.dob,
      mobile: data.mobile.present ? data.mobile.value : this.mobile,
      address: data.address.present ? data.address.value : this.address,
      localPhotoPath: data.localPhotoPath.present
          ? data.localPhotoPath.value
          : this.localPhotoPath,
      remotePhotoUrl: data.remotePhotoUrl.present
          ? data.remotePhotoUrl.value
          : this.remotePhotoUrl,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncAttempts: data.syncAttempts.present
          ? data.syncAttempts.value
          : this.syncAttempts,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      approvalStatus: data.approvalStatus.present
          ? data.approvalStatus.value
          : this.approvalStatus,
      rejectionReason: data.rejectionReason.present
          ? data.rejectionReason.value
          : this.rejectionReason,
      reviewedBy: data.reviewedBy.present
          ? data.reviewedBy.value
          : this.reviewedBy,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentEntryRow(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('name: $name, ')
          ..write('fatherName: $fatherName, ')
          ..write('studentClass: $studentClass, ')
          ..write('division: $division, ')
          ..write('bloodGroup: $bloodGroup, ')
          ..write('dob: $dob, ')
          ..write('mobile: $mobile, ')
          ..write('address: $address, ')
          ..write('localPhotoPath: $localPhotoPath, ')
          ..write('remotePhotoUrl: $remotePhotoUrl, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('syncError: $syncError, ')
          ..write('approvalStatus: $approvalStatus, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('reviewedBy: $reviewedBy, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    schoolId,
    name,
    fatherName,
    studentClass,
    division,
    bloodGroup,
    dob,
    mobile,
    address,
    localPhotoPath,
    remotePhotoUrl,
    syncStatus,
    syncAttempts,
    syncError,
    approvalStatus,
    rejectionReason,
    reviewedBy,
    reviewedAt,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentEntryRow &&
          other.id == this.id &&
          other.schoolId == this.schoolId &&
          other.name == this.name &&
          other.fatherName == this.fatherName &&
          other.studentClass == this.studentClass &&
          other.division == this.division &&
          other.bloodGroup == this.bloodGroup &&
          other.dob == this.dob &&
          other.mobile == this.mobile &&
          other.address == this.address &&
          other.localPhotoPath == this.localPhotoPath &&
          other.remotePhotoUrl == this.remotePhotoUrl &&
          other.syncStatus == this.syncStatus &&
          other.syncAttempts == this.syncAttempts &&
          other.syncError == this.syncError &&
          other.approvalStatus == this.approvalStatus &&
          other.rejectionReason == this.rejectionReason &&
          other.reviewedBy == this.reviewedBy &&
          other.reviewedAt == this.reviewedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StudentEntriesCompanion extends UpdateCompanion<StudentEntryRow> {
  final Value<String> id;
  final Value<String> schoolId;
  final Value<String> name;
  final Value<String> fatherName;
  final Value<String> studentClass;
  final Value<String> division;
  final Value<String> bloodGroup;
  final Value<DateTime?> dob;
  final Value<String> mobile;
  final Value<String> address;
  final Value<String?> localPhotoPath;
  final Value<String?> remotePhotoUrl;
  final Value<String> syncStatus;
  final Value<int> syncAttempts;
  final Value<String?> syncError;
  final Value<String> approvalStatus;
  final Value<String?> rejectionReason;
  final Value<String?> reviewedBy;
  final Value<DateTime?> reviewedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudentEntriesCompanion({
    this.id = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.name = const Value.absent(),
    this.fatherName = const Value.absent(),
    this.studentClass = const Value.absent(),
    this.division = const Value.absent(),
    this.bloodGroup = const Value.absent(),
    this.dob = const Value.absent(),
    this.mobile = const Value.absent(),
    this.address = const Value.absent(),
    this.localPhotoPath = const Value.absent(),
    this.remotePhotoUrl = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.syncError = const Value.absent(),
    this.approvalStatus = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    this.reviewedBy = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentEntriesCompanion.insert({
    required String id,
    required String schoolId,
    this.name = const Value.absent(),
    this.fatherName = const Value.absent(),
    this.studentClass = const Value.absent(),
    this.division = const Value.absent(),
    this.bloodGroup = const Value.absent(),
    this.dob = const Value.absent(),
    this.mobile = const Value.absent(),
    this.address = const Value.absent(),
    this.localPhotoPath = const Value.absent(),
    this.remotePhotoUrl = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.syncError = const Value.absent(),
    this.approvalStatus = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    this.reviewedBy = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schoolId = Value(schoolId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StudentEntryRow> custom({
    Expression<String>? id,
    Expression<String>? schoolId,
    Expression<String>? name,
    Expression<String>? fatherName,
    Expression<String>? studentClass,
    Expression<String>? division,
    Expression<String>? bloodGroup,
    Expression<DateTime>? dob,
    Expression<String>? mobile,
    Expression<String>? address,
    Expression<String>? localPhotoPath,
    Expression<String>? remotePhotoUrl,
    Expression<String>? syncStatus,
    Expression<int>? syncAttempts,
    Expression<String>? syncError,
    Expression<String>? approvalStatus,
    Expression<String>? rejectionReason,
    Expression<String>? reviewedBy,
    Expression<DateTime>? reviewedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schoolId != null) 'school_id': schoolId,
      if (name != null) 'name': name,
      if (fatherName != null) 'father_name': fatherName,
      if (studentClass != null) 'student_class': studentClass,
      if (division != null) 'division': division,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (dob != null) 'dob': dob,
      if (mobile != null) 'mobile': mobile,
      if (address != null) 'address': address,
      if (localPhotoPath != null) 'local_photo_path': localPhotoPath,
      if (remotePhotoUrl != null) 'remote_photo_url': remotePhotoUrl,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncAttempts != null) 'sync_attempts': syncAttempts,
      if (syncError != null) 'sync_error': syncError,
      if (approvalStatus != null) 'approval_status': approvalStatus,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? schoolId,
    Value<String>? name,
    Value<String>? fatherName,
    Value<String>? studentClass,
    Value<String>? division,
    Value<String>? bloodGroup,
    Value<DateTime?>? dob,
    Value<String>? mobile,
    Value<String>? address,
    Value<String?>? localPhotoPath,
    Value<String?>? remotePhotoUrl,
    Value<String>? syncStatus,
    Value<int>? syncAttempts,
    Value<String?>? syncError,
    Value<String>? approvalStatus,
    Value<String?>? rejectionReason,
    Value<String?>? reviewedBy,
    Value<DateTime?>? reviewedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StudentEntriesCompanion(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      studentClass: studentClass ?? this.studentClass,
      division: division ?? this.division,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dob: dob ?? this.dob,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      remotePhotoUrl: remotePhotoUrl ?? this.remotePhotoUrl,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fatherName.present) {
      map['father_name'] = Variable<String>(fatherName.value);
    }
    if (studentClass.present) {
      map['student_class'] = Variable<String>(studentClass.value);
    }
    if (division.present) {
      map['division'] = Variable<String>(division.value);
    }
    if (bloodGroup.present) {
      map['blood_group'] = Variable<String>(bloodGroup.value);
    }
    if (dob.present) {
      map['dob'] = Variable<DateTime>(dob.value);
    }
    if (mobile.present) {
      map['mobile'] = Variable<String>(mobile.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (localPhotoPath.present) {
      map['local_photo_path'] = Variable<String>(localPhotoPath.value);
    }
    if (remotePhotoUrl.present) {
      map['remote_photo_url'] = Variable<String>(remotePhotoUrl.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncAttempts.present) {
      map['sync_attempts'] = Variable<int>(syncAttempts.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (approvalStatus.present) {
      map['approval_status'] = Variable<String>(approvalStatus.value);
    }
    if (rejectionReason.present) {
      map['rejection_reason'] = Variable<String>(rejectionReason.value);
    }
    if (reviewedBy.present) {
      map['reviewed_by'] = Variable<String>(reviewedBy.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentEntriesCompanion(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('name: $name, ')
          ..write('fatherName: $fatherName, ')
          ..write('studentClass: $studentClass, ')
          ..write('division: $division, ')
          ..write('bloodGroup: $bloodGroup, ')
          ..write('dob: $dob, ')
          ..write('mobile: $mobile, ')
          ..write('address: $address, ')
          ..write('localPhotoPath: $localPhotoPath, ')
          ..write('remotePhotoUrl: $remotePhotoUrl, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('syncError: $syncError, ')
          ..write('approvalStatus: $approvalStatus, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('reviewedBy: $reviewedBy, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchoolConfigsTable extends SchoolConfigs
    with TableInfo<$SchoolConfigsTable, SchoolConfigRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchoolConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressLineMeta = const VerificationMeta(
    'addressLine',
  );
  @override
  late final GeneratedColumn<String> addressLine = GeneratedColumn<String>(
    'address_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contactLineMeta = const VerificationMeta(
    'contactLine',
  );
  @override
  late final GeneratedColumn<String> contactLine = GeneratedColumn<String>(
    'contact_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localLogoPathMeta = const VerificationMeta(
    'localLogoPath',
  );
  @override
  late final GeneratedColumn<String> localLogoPath = GeneratedColumn<String>(
    'local_logo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _principalSignatureUrlMeta =
      const VerificationMeta('principalSignatureUrl');
  @override
  late final GeneratedColumn<String> principalSignatureUrl =
      GeneratedColumn<String>(
        'principal_signature_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localPrincipalSignaturePathMeta =
      const VerificationMeta('localPrincipalSignaturePath');
  @override
  late final GeneratedColumn<String> localPrincipalSignaturePath =
      GeneratedColumn<String>(
        'local_principal_signature_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cardSizeIdMeta = const VerificationMeta(
    'cardSizeId',
  );
  @override
  late final GeneratedColumn<String> cardSizeId = GeneratedColumn<String>(
    'card_size_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('v54x86'),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default_vertical'),
  );
  static const VerificationMeta _enabledFieldsMeta = const VerificationMeta(
    'enabledFields',
  );
  @override
  late final GeneratedColumn<String> enabledFields = GeneratedColumn<String>(
    'enabled_fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _primaryColorMeta = const VerificationMeta(
    'primaryColor',
  );
  @override
  late final GeneratedColumn<int> primaryColor = GeneratedColumn<int>(
    'primary_color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFD32F2F),
  );
  static const VerificationMeta _secondaryColorMeta = const VerificationMeta(
    'secondaryColor',
  );
  @override
  late final GeneratedColumn<int> secondaryColor = GeneratedColumn<int>(
    'secondary_color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF1565C0),
  );
  static const VerificationMeta _headerColorMeta = const VerificationMeta(
    'headerColor',
  );
  @override
  late final GeneratedColumn<int> headerColor = GeneratedColumn<int>(
    'header_color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF1565C0),
  );
  static const VerificationMeta _photoBackgroundMeta = const VerificationMeta(
    'photoBackground',
  );
  @override
  late final GeneratedColumn<int> photoBackground = GeneratedColumn<int>(
    'photo_background',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFFFFFFF),
  );
  static const VerificationMeta _divisionColorsMeta = const VerificationMeta(
    'divisionColors',
  );
  @override
  late final GeneratedColumn<String> divisionColors = GeneratedColumn<String>(
    'division_colors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    addressLine,
    contactLine,
    logoUrl,
    localLogoPath,
    principalSignatureUrl,
    localPrincipalSignaturePath,
    cardSizeId,
    templateId,
    enabledFields,
    primaryColor,
    secondaryColor,
    headerColor,
    photoBackground,
    divisionColors,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'school_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchoolConfigRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address_line')) {
      context.handle(
        _addressLineMeta,
        addressLine.isAcceptableOrUnknown(
          data['address_line']!,
          _addressLineMeta,
        ),
      );
    }
    if (data.containsKey('contact_line')) {
      context.handle(
        _contactLineMeta,
        contactLine.isAcceptableOrUnknown(
          data['contact_line']!,
          _contactLineMeta,
        ),
      );
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('local_logo_path')) {
      context.handle(
        _localLogoPathMeta,
        localLogoPath.isAcceptableOrUnknown(
          data['local_logo_path']!,
          _localLogoPathMeta,
        ),
      );
    }
    if (data.containsKey('principal_signature_url')) {
      context.handle(
        _principalSignatureUrlMeta,
        principalSignatureUrl.isAcceptableOrUnknown(
          data['principal_signature_url']!,
          _principalSignatureUrlMeta,
        ),
      );
    }
    if (data.containsKey('local_principal_signature_path')) {
      context.handle(
        _localPrincipalSignaturePathMeta,
        localPrincipalSignaturePath.isAcceptableOrUnknown(
          data['local_principal_signature_path']!,
          _localPrincipalSignaturePathMeta,
        ),
      );
    }
    if (data.containsKey('card_size_id')) {
      context.handle(
        _cardSizeIdMeta,
        cardSizeId.isAcceptableOrUnknown(
          data['card_size_id']!,
          _cardSizeIdMeta,
        ),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('enabled_fields')) {
      context.handle(
        _enabledFieldsMeta,
        enabledFields.isAcceptableOrUnknown(
          data['enabled_fields']!,
          _enabledFieldsMeta,
        ),
      );
    }
    if (data.containsKey('primary_color')) {
      context.handle(
        _primaryColorMeta,
        primaryColor.isAcceptableOrUnknown(
          data['primary_color']!,
          _primaryColorMeta,
        ),
      );
    }
    if (data.containsKey('secondary_color')) {
      context.handle(
        _secondaryColorMeta,
        secondaryColor.isAcceptableOrUnknown(
          data['secondary_color']!,
          _secondaryColorMeta,
        ),
      );
    }
    if (data.containsKey('header_color')) {
      context.handle(
        _headerColorMeta,
        headerColor.isAcceptableOrUnknown(
          data['header_color']!,
          _headerColorMeta,
        ),
      );
    }
    if (data.containsKey('photo_background')) {
      context.handle(
        _photoBackgroundMeta,
        photoBackground.isAcceptableOrUnknown(
          data['photo_background']!,
          _photoBackgroundMeta,
        ),
      );
    }
    if (data.containsKey('division_colors')) {
      context.handle(
        _divisionColorsMeta,
        divisionColors.isAcceptableOrUnknown(
          data['division_colors']!,
          _divisionColorsMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SchoolConfigRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchoolConfigRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      addressLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_line'],
      )!,
      contactLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_line'],
      )!,
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      localLogoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_logo_path'],
      ),
      principalSignatureUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}principal_signature_url'],
      ),
      localPrincipalSignaturePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_principal_signature_path'],
      ),
      cardSizeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_size_id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      enabledFields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_fields'],
      )!,
      primaryColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}primary_color'],
      )!,
      secondaryColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}secondary_color'],
      )!,
      headerColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}header_color'],
      )!,
      photoBackground: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_background'],
      )!,
      divisionColors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}division_colors'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $SchoolConfigsTable createAlias(String alias) {
    return $SchoolConfigsTable(attachedDatabase, alias);
  }
}

class SchoolConfigRow extends DataClass implements Insertable<SchoolConfigRow> {
  final String id;
  final String name;
  final String addressLine;
  final String contactLine;
  final String? logoUrl;
  final String? localLogoPath;
  final String? principalSignatureUrl;
  final String? localPrincipalSignaturePath;
  final String cardSizeId;
  final String templateId;

  /// Comma-separated `StudentField.key` values. A join table would be more
  /// normalised but this set is tiny, always read whole, and never queried by
  /// member - the simpler shape wins.
  final String enabledFields;
  final int primaryColor;
  final int secondaryColor;
  final int headerColor;
  final int photoBackground;

  /// JSON object of division -> ARGB int, e.g. `{"A":4294901760}`.
  ///
  /// JSON rather than the comma-joined shape used by [enabledFields] because
  /// this is key/value rather than a flat set, and a hand-edited value with a
  /// stray delimiter would silently mis-colour cards.
  final String divisionColors;
  final DateTime? updatedAt;
  const SchoolConfigRow({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.contactLine,
    this.logoUrl,
    this.localLogoPath,
    this.principalSignatureUrl,
    this.localPrincipalSignaturePath,
    required this.cardSizeId,
    required this.templateId,
    required this.enabledFields,
    required this.primaryColor,
    required this.secondaryColor,
    required this.headerColor,
    required this.photoBackground,
    required this.divisionColors,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['address_line'] = Variable<String>(addressLine);
    map['contact_line'] = Variable<String>(contactLine);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || localLogoPath != null) {
      map['local_logo_path'] = Variable<String>(localLogoPath);
    }
    if (!nullToAbsent || principalSignatureUrl != null) {
      map['principal_signature_url'] = Variable<String>(principalSignatureUrl);
    }
    if (!nullToAbsent || localPrincipalSignaturePath != null) {
      map['local_principal_signature_path'] = Variable<String>(
        localPrincipalSignaturePath,
      );
    }
    map['card_size_id'] = Variable<String>(cardSizeId);
    map['template_id'] = Variable<String>(templateId);
    map['enabled_fields'] = Variable<String>(enabledFields);
    map['primary_color'] = Variable<int>(primaryColor);
    map['secondary_color'] = Variable<int>(secondaryColor);
    map['header_color'] = Variable<int>(headerColor);
    map['photo_background'] = Variable<int>(photoBackground);
    map['division_colors'] = Variable<String>(divisionColors);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  SchoolConfigsCompanion toCompanion(bool nullToAbsent) {
    return SchoolConfigsCompanion(
      id: Value(id),
      name: Value(name),
      addressLine: Value(addressLine),
      contactLine: Value(contactLine),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      localLogoPath: localLogoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localLogoPath),
      principalSignatureUrl: principalSignatureUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(principalSignatureUrl),
      localPrincipalSignaturePath:
          localPrincipalSignaturePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPrincipalSignaturePath),
      cardSizeId: Value(cardSizeId),
      templateId: Value(templateId),
      enabledFields: Value(enabledFields),
      primaryColor: Value(primaryColor),
      secondaryColor: Value(secondaryColor),
      headerColor: Value(headerColor),
      photoBackground: Value(photoBackground),
      divisionColors: Value(divisionColors),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SchoolConfigRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchoolConfigRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      addressLine: serializer.fromJson<String>(json['addressLine']),
      contactLine: serializer.fromJson<String>(json['contactLine']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      localLogoPath: serializer.fromJson<String?>(json['localLogoPath']),
      principalSignatureUrl: serializer.fromJson<String?>(
        json['principalSignatureUrl'],
      ),
      localPrincipalSignaturePath: serializer.fromJson<String?>(
        json['localPrincipalSignaturePath'],
      ),
      cardSizeId: serializer.fromJson<String>(json['cardSizeId']),
      templateId: serializer.fromJson<String>(json['templateId']),
      enabledFields: serializer.fromJson<String>(json['enabledFields']),
      primaryColor: serializer.fromJson<int>(json['primaryColor']),
      secondaryColor: serializer.fromJson<int>(json['secondaryColor']),
      headerColor: serializer.fromJson<int>(json['headerColor']),
      photoBackground: serializer.fromJson<int>(json['photoBackground']),
      divisionColors: serializer.fromJson<String>(json['divisionColors']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'addressLine': serializer.toJson<String>(addressLine),
      'contactLine': serializer.toJson<String>(contactLine),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'localLogoPath': serializer.toJson<String?>(localLogoPath),
      'principalSignatureUrl': serializer.toJson<String?>(
        principalSignatureUrl,
      ),
      'localPrincipalSignaturePath': serializer.toJson<String?>(
        localPrincipalSignaturePath,
      ),
      'cardSizeId': serializer.toJson<String>(cardSizeId),
      'templateId': serializer.toJson<String>(templateId),
      'enabledFields': serializer.toJson<String>(enabledFields),
      'primaryColor': serializer.toJson<int>(primaryColor),
      'secondaryColor': serializer.toJson<int>(secondaryColor),
      'headerColor': serializer.toJson<int>(headerColor),
      'photoBackground': serializer.toJson<int>(photoBackground),
      'divisionColors': serializer.toJson<String>(divisionColors),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  SchoolConfigRow copyWith({
    String? id,
    String? name,
    String? addressLine,
    String? contactLine,
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> localLogoPath = const Value.absent(),
    Value<String?> principalSignatureUrl = const Value.absent(),
    Value<String?> localPrincipalSignaturePath = const Value.absent(),
    String? cardSizeId,
    String? templateId,
    String? enabledFields,
    int? primaryColor,
    int? secondaryColor,
    int? headerColor,
    int? photoBackground,
    String? divisionColors,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => SchoolConfigRow(
    id: id ?? this.id,
    name: name ?? this.name,
    addressLine: addressLine ?? this.addressLine,
    contactLine: contactLine ?? this.contactLine,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    localLogoPath: localLogoPath.present
        ? localLogoPath.value
        : this.localLogoPath,
    principalSignatureUrl: principalSignatureUrl.present
        ? principalSignatureUrl.value
        : this.principalSignatureUrl,
    localPrincipalSignaturePath: localPrincipalSignaturePath.present
        ? localPrincipalSignaturePath.value
        : this.localPrincipalSignaturePath,
    cardSizeId: cardSizeId ?? this.cardSizeId,
    templateId: templateId ?? this.templateId,
    enabledFields: enabledFields ?? this.enabledFields,
    primaryColor: primaryColor ?? this.primaryColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    headerColor: headerColor ?? this.headerColor,
    photoBackground: photoBackground ?? this.photoBackground,
    divisionColors: divisionColors ?? this.divisionColors,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  SchoolConfigRow copyWithCompanion(SchoolConfigsCompanion data) {
    return SchoolConfigRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      addressLine: data.addressLine.present
          ? data.addressLine.value
          : this.addressLine,
      contactLine: data.contactLine.present
          ? data.contactLine.value
          : this.contactLine,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      localLogoPath: data.localLogoPath.present
          ? data.localLogoPath.value
          : this.localLogoPath,
      principalSignatureUrl: data.principalSignatureUrl.present
          ? data.principalSignatureUrl.value
          : this.principalSignatureUrl,
      localPrincipalSignaturePath: data.localPrincipalSignaturePath.present
          ? data.localPrincipalSignaturePath.value
          : this.localPrincipalSignaturePath,
      cardSizeId: data.cardSizeId.present
          ? data.cardSizeId.value
          : this.cardSizeId,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      enabledFields: data.enabledFields.present
          ? data.enabledFields.value
          : this.enabledFields,
      primaryColor: data.primaryColor.present
          ? data.primaryColor.value
          : this.primaryColor,
      secondaryColor: data.secondaryColor.present
          ? data.secondaryColor.value
          : this.secondaryColor,
      headerColor: data.headerColor.present
          ? data.headerColor.value
          : this.headerColor,
      photoBackground: data.photoBackground.present
          ? data.photoBackground.value
          : this.photoBackground,
      divisionColors: data.divisionColors.present
          ? data.divisionColors.value
          : this.divisionColors,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchoolConfigRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('addressLine: $addressLine, ')
          ..write('contactLine: $contactLine, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('localLogoPath: $localLogoPath, ')
          ..write('principalSignatureUrl: $principalSignatureUrl, ')
          ..write('localPrincipalSignaturePath: $localPrincipalSignaturePath, ')
          ..write('cardSizeId: $cardSizeId, ')
          ..write('templateId: $templateId, ')
          ..write('enabledFields: $enabledFields, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('headerColor: $headerColor, ')
          ..write('photoBackground: $photoBackground, ')
          ..write('divisionColors: $divisionColors, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    addressLine,
    contactLine,
    logoUrl,
    localLogoPath,
    principalSignatureUrl,
    localPrincipalSignaturePath,
    cardSizeId,
    templateId,
    enabledFields,
    primaryColor,
    secondaryColor,
    headerColor,
    photoBackground,
    divisionColors,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchoolConfigRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.addressLine == this.addressLine &&
          other.contactLine == this.contactLine &&
          other.logoUrl == this.logoUrl &&
          other.localLogoPath == this.localLogoPath &&
          other.principalSignatureUrl == this.principalSignatureUrl &&
          other.localPrincipalSignaturePath ==
              this.localPrincipalSignaturePath &&
          other.cardSizeId == this.cardSizeId &&
          other.templateId == this.templateId &&
          other.enabledFields == this.enabledFields &&
          other.primaryColor == this.primaryColor &&
          other.secondaryColor == this.secondaryColor &&
          other.headerColor == this.headerColor &&
          other.photoBackground == this.photoBackground &&
          other.divisionColors == this.divisionColors &&
          other.updatedAt == this.updatedAt);
}

class SchoolConfigsCompanion extends UpdateCompanion<SchoolConfigRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> addressLine;
  final Value<String> contactLine;
  final Value<String?> logoUrl;
  final Value<String?> localLogoPath;
  final Value<String?> principalSignatureUrl;
  final Value<String?> localPrincipalSignaturePath;
  final Value<String> cardSizeId;
  final Value<String> templateId;
  final Value<String> enabledFields;
  final Value<int> primaryColor;
  final Value<int> secondaryColor;
  final Value<int> headerColor;
  final Value<int> photoBackground;
  final Value<String> divisionColors;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const SchoolConfigsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.addressLine = const Value.absent(),
    this.contactLine = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.localLogoPath = const Value.absent(),
    this.principalSignatureUrl = const Value.absent(),
    this.localPrincipalSignaturePath = const Value.absent(),
    this.cardSizeId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.enabledFields = const Value.absent(),
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    this.headerColor = const Value.absent(),
    this.photoBackground = const Value.absent(),
    this.divisionColors = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchoolConfigsCompanion.insert({
    required String id,
    required String name,
    this.addressLine = const Value.absent(),
    this.contactLine = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.localLogoPath = const Value.absent(),
    this.principalSignatureUrl = const Value.absent(),
    this.localPrincipalSignaturePath = const Value.absent(),
    this.cardSizeId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.enabledFields = const Value.absent(),
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    this.headerColor = const Value.absent(),
    this.photoBackground = const Value.absent(),
    this.divisionColors = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<SchoolConfigRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? addressLine,
    Expression<String>? contactLine,
    Expression<String>? logoUrl,
    Expression<String>? localLogoPath,
    Expression<String>? principalSignatureUrl,
    Expression<String>? localPrincipalSignaturePath,
    Expression<String>? cardSizeId,
    Expression<String>? templateId,
    Expression<String>? enabledFields,
    Expression<int>? primaryColor,
    Expression<int>? secondaryColor,
    Expression<int>? headerColor,
    Expression<int>? photoBackground,
    Expression<String>? divisionColors,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (addressLine != null) 'address_line': addressLine,
      if (contactLine != null) 'contact_line': contactLine,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (localLogoPath != null) 'local_logo_path': localLogoPath,
      if (principalSignatureUrl != null)
        'principal_signature_url': principalSignatureUrl,
      if (localPrincipalSignaturePath != null)
        'local_principal_signature_path': localPrincipalSignaturePath,
      if (cardSizeId != null) 'card_size_id': cardSizeId,
      if (templateId != null) 'template_id': templateId,
      if (enabledFields != null) 'enabled_fields': enabledFields,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (headerColor != null) 'header_color': headerColor,
      if (photoBackground != null) 'photo_background': photoBackground,
      if (divisionColors != null) 'division_colors': divisionColors,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchoolConfigsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? addressLine,
    Value<String>? contactLine,
    Value<String?>? logoUrl,
    Value<String?>? localLogoPath,
    Value<String?>? principalSignatureUrl,
    Value<String?>? localPrincipalSignaturePath,
    Value<String>? cardSizeId,
    Value<String>? templateId,
    Value<String>? enabledFields,
    Value<int>? primaryColor,
    Value<int>? secondaryColor,
    Value<int>? headerColor,
    Value<int>? photoBackground,
    Value<String>? divisionColors,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return SchoolConfigsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLine: addressLine ?? this.addressLine,
      contactLine: contactLine ?? this.contactLine,
      logoUrl: logoUrl ?? this.logoUrl,
      localLogoPath: localLogoPath ?? this.localLogoPath,
      principalSignatureUrl:
          principalSignatureUrl ?? this.principalSignatureUrl,
      localPrincipalSignaturePath:
          localPrincipalSignaturePath ?? this.localPrincipalSignaturePath,
      cardSizeId: cardSizeId ?? this.cardSizeId,
      templateId: templateId ?? this.templateId,
      enabledFields: enabledFields ?? this.enabledFields,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      headerColor: headerColor ?? this.headerColor,
      photoBackground: photoBackground ?? this.photoBackground,
      divisionColors: divisionColors ?? this.divisionColors,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (addressLine.present) {
      map['address_line'] = Variable<String>(addressLine.value);
    }
    if (contactLine.present) {
      map['contact_line'] = Variable<String>(contactLine.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (localLogoPath.present) {
      map['local_logo_path'] = Variable<String>(localLogoPath.value);
    }
    if (principalSignatureUrl.present) {
      map['principal_signature_url'] = Variable<String>(
        principalSignatureUrl.value,
      );
    }
    if (localPrincipalSignaturePath.present) {
      map['local_principal_signature_path'] = Variable<String>(
        localPrincipalSignaturePath.value,
      );
    }
    if (cardSizeId.present) {
      map['card_size_id'] = Variable<String>(cardSizeId.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (enabledFields.present) {
      map['enabled_fields'] = Variable<String>(enabledFields.value);
    }
    if (primaryColor.present) {
      map['primary_color'] = Variable<int>(primaryColor.value);
    }
    if (secondaryColor.present) {
      map['secondary_color'] = Variable<int>(secondaryColor.value);
    }
    if (headerColor.present) {
      map['header_color'] = Variable<int>(headerColor.value);
    }
    if (photoBackground.present) {
      map['photo_background'] = Variable<int>(photoBackground.value);
    }
    if (divisionColors.present) {
      map['division_colors'] = Variable<String>(divisionColors.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchoolConfigsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('addressLine: $addressLine, ')
          ..write('contactLine: $contactLine, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('localLogoPath: $localLogoPath, ')
          ..write('principalSignatureUrl: $principalSignatureUrl, ')
          ..write('localPrincipalSignaturePath: $localPrincipalSignaturePath, ')
          ..write('cardSizeId: $cardSizeId, ')
          ..write('templateId: $templateId, ')
          ..write('enabledFields: $enabledFields, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('headerColor: $headerColor, ')
          ..write('photoBackground: $photoBackground, ')
          ..write('divisionColors: $divisionColors, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorUidMeta = const VerificationMeta(
    'actorUid',
  );
  @override
  late final GeneratedColumn<String> actorUid = GeneratedColumn<String>(
    'actor_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    action,
    entityType,
    entityId,
    actorUid,
    details,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('actor_uid')) {
      context.handle(
        _actorUidMeta,
        actorUid.isAcceptableOrUnknown(data['actor_uid']!, _actorUidMeta),
      );
    } else if (isInserting) {
      context.missing(_actorUidMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      actorUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_uid'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLogRow extends DataClass implements Insertable<AuditLogRow> {
  final int id;

  /// Machine-readable verb: 'approve', 'reject', 'export_csv',
  /// 'print_batch', 'create_school', 'update_school', 'sync_pass'.
  final String action;

  /// What kind of entity was affected: 'student', 'school', 'print_batch'.
  final String entityType;

  /// The id of the affected entity (student id, school id, batch id).
  final String entityId;

  /// Auth UID of the admin who performed the action.
  final String actorUid;

  /// Free-form JSON blob with extra context. Kept as text so the table stays
  /// flat and a new detail field never requires a migration.
  final String details;
  final DateTime createdAt;
  const AuditLogRow({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorUid,
    required this.details,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action'] = Variable<String>(action);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['actor_uid'] = Variable<String>(actorUid);
    map['details'] = Variable<String>(details);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      action: Value(action),
      entityType: Value(entityType),
      entityId: Value(entityId),
      actorUid: Value(actorUid),
      details: Value(details),
      createdAt: Value(createdAt),
    );
  }

  factory AuditLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogRow(
      id: serializer.fromJson<int>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      actorUid: serializer.fromJson<String>(json['actorUid']),
      details: serializer.fromJson<String>(json['details']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'action': serializer.toJson<String>(action),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'actorUid': serializer.toJson<String>(actorUid),
      'details': serializer.toJson<String>(details),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AuditLogRow copyWith({
    int? id,
    String? action,
    String? entityType,
    String? entityId,
    String? actorUid,
    String? details,
    DateTime? createdAt,
  }) => AuditLogRow(
    id: id ?? this.id,
    action: action ?? this.action,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    actorUid: actorUid ?? this.actorUid,
    details: details ?? this.details,
    createdAt: createdAt ?? this.createdAt,
  );
  AuditLogRow copyWithCompanion(AuditLogsCompanion data) {
    return AuditLogRow(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      actorUid: data.actorUid.present ? data.actorUid.value : this.actorUid,
      details: data.details.present ? data.details.value : this.details,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogRow(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('actorUid: $actorUid, ')
          ..write('details: $details, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    action,
    entityType,
    entityId,
    actorUid,
    details,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogRow &&
          other.id == this.id &&
          other.action == this.action &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.actorUid == this.actorUid &&
          other.details == this.details &&
          other.createdAt == this.createdAt);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLogRow> {
  final Value<int> id;
  final Value<String> action;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> actorUid;
  final Value<String> details;
  final Value<DateTime> createdAt;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.actorUid = const Value.absent(),
    this.details = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.id = const Value.absent(),
    required String action,
    required String entityType,
    required String entityId,
    required String actorUid,
    this.details = const Value.absent(),
    required DateTime createdAt,
  }) : action = Value(action),
       entityType = Value(entityType),
       entityId = Value(entityId),
       actorUid = Value(actorUid),
       createdAt = Value(createdAt);
  static Insertable<AuditLogRow> custom({
    Expression<int>? id,
    Expression<String>? action,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? actorUid,
    Expression<String>? details,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (actorUid != null) 'actor_uid': actorUid,
      if (details != null) 'details': details,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AuditLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? action,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? actorUid,
    Value<String>? details,
    Value<DateTime>? createdAt,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      actorUid: actorUid ?? this.actorUid,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (actorUid.present) {
      map['actor_uid'] = Variable<String>(actorUid.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('actorUid: $actorUid, ')
          ..write('details: $details, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PrintBatchesTable extends PrintBatches
    with TableInfo<$PrintBatchesTable, PrintBatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrintBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardCountMeta = const VerificationMeta(
    'cardCount',
  );
  @override
  late final GeneratedColumn<int> cardCount = GeneratedColumn<int>(
    'card_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sheetTypeMeta = const VerificationMeta(
    'sheetType',
  );
  @override
  late final GeneratedColumn<String> sheetType = GeneratedColumn<String>(
    'sheet_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sheetCountMeta = const VerificationMeta(
    'sheetCount',
  );
  @override
  late final GeneratedColumn<int> sheetCount = GeneratedColumn<int>(
    'sheet_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedByMeta = const VerificationMeta(
    'generatedBy',
  );
  @override
  late final GeneratedColumn<String> generatedBy = GeneratedColumn<String>(
    'generated_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schoolId,
    cardCount,
    sheetType,
    sheetCount,
    generatedBy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'print_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrintBatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('card_count')) {
      context.handle(
        _cardCountMeta,
        cardCount.isAcceptableOrUnknown(data['card_count']!, _cardCountMeta),
      );
    } else if (isInserting) {
      context.missing(_cardCountMeta);
    }
    if (data.containsKey('sheet_type')) {
      context.handle(
        _sheetTypeMeta,
        sheetType.isAcceptableOrUnknown(data['sheet_type']!, _sheetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetTypeMeta);
    }
    if (data.containsKey('sheet_count')) {
      context.handle(
        _sheetCountMeta,
        sheetCount.isAcceptableOrUnknown(data['sheet_count']!, _sheetCountMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetCountMeta);
    }
    if (data.containsKey('generated_by')) {
      context.handle(
        _generatedByMeta,
        generatedBy.isAcceptableOrUnknown(
          data['generated_by']!,
          _generatedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrintBatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrintBatchRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      cardCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_count'],
      )!,
      sheetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sheet_type'],
      )!,
      sheetCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sheet_count'],
      )!,
      generatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generated_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PrintBatchesTable createAlias(String alias) {
    return $PrintBatchesTable(attachedDatabase, alias);
  }
}

class PrintBatchRow extends DataClass implements Insertable<PrintBatchRow> {
  final String id;
  final String schoolId;
  final int cardCount;

  /// '12x18', 'a4', or 'single'.
  final String sheetType;
  final int sheetCount;

  /// Auth UID of the admin who triggered the print run.
  final String generatedBy;
  final DateTime createdAt;
  const PrintBatchRow({
    required this.id,
    required this.schoolId,
    required this.cardCount,
    required this.sheetType,
    required this.sheetCount,
    required this.generatedBy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['school_id'] = Variable<String>(schoolId);
    map['card_count'] = Variable<int>(cardCount);
    map['sheet_type'] = Variable<String>(sheetType);
    map['sheet_count'] = Variable<int>(sheetCount);
    map['generated_by'] = Variable<String>(generatedBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PrintBatchesCompanion toCompanion(bool nullToAbsent) {
    return PrintBatchesCompanion(
      id: Value(id),
      schoolId: Value(schoolId),
      cardCount: Value(cardCount),
      sheetType: Value(sheetType),
      sheetCount: Value(sheetCount),
      generatedBy: Value(generatedBy),
      createdAt: Value(createdAt),
    );
  }

  factory PrintBatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrintBatchRow(
      id: serializer.fromJson<String>(json['id']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      cardCount: serializer.fromJson<int>(json['cardCount']),
      sheetType: serializer.fromJson<String>(json['sheetType']),
      sheetCount: serializer.fromJson<int>(json['sheetCount']),
      generatedBy: serializer.fromJson<String>(json['generatedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schoolId': serializer.toJson<String>(schoolId),
      'cardCount': serializer.toJson<int>(cardCount),
      'sheetType': serializer.toJson<String>(sheetType),
      'sheetCount': serializer.toJson<int>(sheetCount),
      'generatedBy': serializer.toJson<String>(generatedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PrintBatchRow copyWith({
    String? id,
    String? schoolId,
    int? cardCount,
    String? sheetType,
    int? sheetCount,
    String? generatedBy,
    DateTime? createdAt,
  }) => PrintBatchRow(
    id: id ?? this.id,
    schoolId: schoolId ?? this.schoolId,
    cardCount: cardCount ?? this.cardCount,
    sheetType: sheetType ?? this.sheetType,
    sheetCount: sheetCount ?? this.sheetCount,
    generatedBy: generatedBy ?? this.generatedBy,
    createdAt: createdAt ?? this.createdAt,
  );
  PrintBatchRow copyWithCompanion(PrintBatchesCompanion data) {
    return PrintBatchRow(
      id: data.id.present ? data.id.value : this.id,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      cardCount: data.cardCount.present ? data.cardCount.value : this.cardCount,
      sheetType: data.sheetType.present ? data.sheetType.value : this.sheetType,
      sheetCount: data.sheetCount.present
          ? data.sheetCount.value
          : this.sheetCount,
      generatedBy: data.generatedBy.present
          ? data.generatedBy.value
          : this.generatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrintBatchRow(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('cardCount: $cardCount, ')
          ..write('sheetType: $sheetType, ')
          ..write('sheetCount: $sheetCount, ')
          ..write('generatedBy: $generatedBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schoolId,
    cardCount,
    sheetType,
    sheetCount,
    generatedBy,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrintBatchRow &&
          other.id == this.id &&
          other.schoolId == this.schoolId &&
          other.cardCount == this.cardCount &&
          other.sheetType == this.sheetType &&
          other.sheetCount == this.sheetCount &&
          other.generatedBy == this.generatedBy &&
          other.createdAt == this.createdAt);
}

class PrintBatchesCompanion extends UpdateCompanion<PrintBatchRow> {
  final Value<String> id;
  final Value<String> schoolId;
  final Value<int> cardCount;
  final Value<String> sheetType;
  final Value<int> sheetCount;
  final Value<String> generatedBy;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PrintBatchesCompanion({
    this.id = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.cardCount = const Value.absent(),
    this.sheetType = const Value.absent(),
    this.sheetCount = const Value.absent(),
    this.generatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrintBatchesCompanion.insert({
    required String id,
    required String schoolId,
    required int cardCount,
    required String sheetType,
    required int sheetCount,
    required String generatedBy,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schoolId = Value(schoolId),
       cardCount = Value(cardCount),
       sheetType = Value(sheetType),
       sheetCount = Value(sheetCount),
       generatedBy = Value(generatedBy),
       createdAt = Value(createdAt);
  static Insertable<PrintBatchRow> custom({
    Expression<String>? id,
    Expression<String>? schoolId,
    Expression<int>? cardCount,
    Expression<String>? sheetType,
    Expression<int>? sheetCount,
    Expression<String>? generatedBy,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schoolId != null) 'school_id': schoolId,
      if (cardCount != null) 'card_count': cardCount,
      if (sheetType != null) 'sheet_type': sheetType,
      if (sheetCount != null) 'sheet_count': sheetCount,
      if (generatedBy != null) 'generated_by': generatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrintBatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? schoolId,
    Value<int>? cardCount,
    Value<String>? sheetType,
    Value<int>? sheetCount,
    Value<String>? generatedBy,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PrintBatchesCompanion(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      cardCount: cardCount ?? this.cardCount,
      sheetType: sheetType ?? this.sheetType,
      sheetCount: sheetCount ?? this.sheetCount,
      generatedBy: generatedBy ?? this.generatedBy,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (cardCount.present) {
      map['card_count'] = Variable<int>(cardCount.value);
    }
    if (sheetType.present) {
      map['sheet_type'] = Variable<String>(sheetType.value);
    }
    if (sheetCount.present) {
      map['sheet_count'] = Variable<int>(sheetCount.value);
    }
    if (generatedBy.present) {
      map['generated_by'] = Variable<String>(generatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrintBatchesCompanion(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('cardCount: $cardCount, ')
          ..write('sheetType: $sheetType, ')
          ..write('sheetCount: $sheetCount, ')
          ..write('generatedBy: $generatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StudentEntriesTable studentEntries = $StudentEntriesTable(this);
  late final $SchoolConfigsTable schoolConfigs = $SchoolConfigsTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $PrintBatchesTable printBatches = $PrintBatchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    studentEntries,
    schoolConfigs,
    auditLogs,
    printBatches,
  ];
}

typedef $$StudentEntriesTableCreateCompanionBuilder =
    StudentEntriesCompanion Function({
      required String id,
      required String schoolId,
      Value<String> name,
      Value<String> fatherName,
      Value<String> studentClass,
      Value<String> division,
      Value<String> bloodGroup,
      Value<DateTime?> dob,
      Value<String> mobile,
      Value<String> address,
      Value<String?> localPhotoPath,
      Value<String?> remotePhotoUrl,
      Value<String> syncStatus,
      Value<int> syncAttempts,
      Value<String?> syncError,
      Value<String> approvalStatus,
      Value<String?> rejectionReason,
      Value<String?> reviewedBy,
      Value<DateTime?> reviewedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StudentEntriesTableUpdateCompanionBuilder =
    StudentEntriesCompanion Function({
      Value<String> id,
      Value<String> schoolId,
      Value<String> name,
      Value<String> fatherName,
      Value<String> studentClass,
      Value<String> division,
      Value<String> bloodGroup,
      Value<DateTime?> dob,
      Value<String> mobile,
      Value<String> address,
      Value<String?> localPhotoPath,
      Value<String?> remotePhotoUrl,
      Value<String> syncStatus,
      Value<int> syncAttempts,
      Value<String?> syncError,
      Value<String> approvalStatus,
      Value<String?> rejectionReason,
      Value<String?> reviewedBy,
      Value<DateTime?> reviewedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StudentEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $StudentEntriesTable> {
  $$StudentEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fatherName => $composableBuilder(
    column: $table.fatherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentClass => $composableBuilder(
    column: $table.studentClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bloodGroup => $composableBuilder(
    column: $table.bloodGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dob => $composableBuilder(
    column: $table.dob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mobile => $composableBuilder(
    column: $table.mobile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePhotoUrl => $composableBuilder(
    column: $table.remotePhotoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncAttempts => $composableBuilder(
    column: $table.syncAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedBy => $composableBuilder(
    column: $table.reviewedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudentEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentEntriesTable> {
  $$StudentEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fatherName => $composableBuilder(
    column: $table.fatherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentClass => $composableBuilder(
    column: $table.studentClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bloodGroup => $composableBuilder(
    column: $table.bloodGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dob => $composableBuilder(
    column: $table.dob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mobile => $composableBuilder(
    column: $table.mobile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePhotoUrl => $composableBuilder(
    column: $table.remotePhotoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncAttempts => $composableBuilder(
    column: $table.syncAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedBy => $composableBuilder(
    column: $table.reviewedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudentEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentEntriesTable> {
  $$StudentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get fatherName => $composableBuilder(
    column: $table.fatherName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get studentClass => $composableBuilder(
    column: $table.studentClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get division =>
      $composableBuilder(column: $table.division, builder: (column) => column);

  GeneratedColumn<String> get bloodGroup => $composableBuilder(
    column: $table.bloodGroup,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dob =>
      $composableBuilder(column: $table.dob, builder: (column) => column);

  GeneratedColumn<String> get mobile =>
      $composableBuilder(column: $table.mobile, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remotePhotoUrl => $composableBuilder(
    column: $table.remotePhotoUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncAttempts => $composableBuilder(
    column: $table.syncAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get approvalStatus => $composableBuilder(
    column: $table.approvalStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewedBy => $composableBuilder(
    column: $table.reviewedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StudentEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentEntriesTable,
          StudentEntryRow,
          $$StudentEntriesTableFilterComposer,
          $$StudentEntriesTableOrderingComposer,
          $$StudentEntriesTableAnnotationComposer,
          $$StudentEntriesTableCreateCompanionBuilder,
          $$StudentEntriesTableUpdateCompanionBuilder,
          (
            StudentEntryRow,
            BaseReferences<
              _$AppDatabase,
              $StudentEntriesTable,
              StudentEntryRow
            >,
          ),
          StudentEntryRow,
          PrefetchHooks Function()
        > {
  $$StudentEntriesTableTableManager(
    _$AppDatabase db,
    $StudentEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> fatherName = const Value.absent(),
                Value<String> studentClass = const Value.absent(),
                Value<String> division = const Value.absent(),
                Value<String> bloodGroup = const Value.absent(),
                Value<DateTime?> dob = const Value.absent(),
                Value<String> mobile = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String?> localPhotoPath = const Value.absent(),
                Value<String?> remotePhotoUrl = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> syncAttempts = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> approvalStatus = const Value.absent(),
                Value<String?> rejectionReason = const Value.absent(),
                Value<String?> reviewedBy = const Value.absent(),
                Value<DateTime?> reviewedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentEntriesCompanion(
                id: id,
                schoolId: schoolId,
                name: name,
                fatherName: fatherName,
                studentClass: studentClass,
                division: division,
                bloodGroup: bloodGroup,
                dob: dob,
                mobile: mobile,
                address: address,
                localPhotoPath: localPhotoPath,
                remotePhotoUrl: remotePhotoUrl,
                syncStatus: syncStatus,
                syncAttempts: syncAttempts,
                syncError: syncError,
                approvalStatus: approvalStatus,
                rejectionReason: rejectionReason,
                reviewedBy: reviewedBy,
                reviewedAt: reviewedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String schoolId,
                Value<String> name = const Value.absent(),
                Value<String> fatherName = const Value.absent(),
                Value<String> studentClass = const Value.absent(),
                Value<String> division = const Value.absent(),
                Value<String> bloodGroup = const Value.absent(),
                Value<DateTime?> dob = const Value.absent(),
                Value<String> mobile = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String?> localPhotoPath = const Value.absent(),
                Value<String?> remotePhotoUrl = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> syncAttempts = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> approvalStatus = const Value.absent(),
                Value<String?> rejectionReason = const Value.absent(),
                Value<String?> reviewedBy = const Value.absent(),
                Value<DateTime?> reviewedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StudentEntriesCompanion.insert(
                id: id,
                schoolId: schoolId,
                name: name,
                fatherName: fatherName,
                studentClass: studentClass,
                division: division,
                bloodGroup: bloodGroup,
                dob: dob,
                mobile: mobile,
                address: address,
                localPhotoPath: localPhotoPath,
                remotePhotoUrl: remotePhotoUrl,
                syncStatus: syncStatus,
                syncAttempts: syncAttempts,
                syncError: syncError,
                approvalStatus: approvalStatus,
                rejectionReason: rejectionReason,
                reviewedBy: reviewedBy,
                reviewedAt: reviewedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudentEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentEntriesTable,
      StudentEntryRow,
      $$StudentEntriesTableFilterComposer,
      $$StudentEntriesTableOrderingComposer,
      $$StudentEntriesTableAnnotationComposer,
      $$StudentEntriesTableCreateCompanionBuilder,
      $$StudentEntriesTableUpdateCompanionBuilder,
      (
        StudentEntryRow,
        BaseReferences<_$AppDatabase, $StudentEntriesTable, StudentEntryRow>,
      ),
      StudentEntryRow,
      PrefetchHooks Function()
    >;
typedef $$SchoolConfigsTableCreateCompanionBuilder =
    SchoolConfigsCompanion Function({
      required String id,
      required String name,
      Value<String> addressLine,
      Value<String> contactLine,
      Value<String?> logoUrl,
      Value<String?> localLogoPath,
      Value<String?> principalSignatureUrl,
      Value<String?> localPrincipalSignaturePath,
      Value<String> cardSizeId,
      Value<String> templateId,
      Value<String> enabledFields,
      Value<int> primaryColor,
      Value<int> secondaryColor,
      Value<int> headerColor,
      Value<int> photoBackground,
      Value<String> divisionColors,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$SchoolConfigsTableUpdateCompanionBuilder =
    SchoolConfigsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> addressLine,
      Value<String> contactLine,
      Value<String?> logoUrl,
      Value<String?> localLogoPath,
      Value<String?> principalSignatureUrl,
      Value<String?> localPrincipalSignaturePath,
      Value<String> cardSizeId,
      Value<String> templateId,
      Value<String> enabledFields,
      Value<int> primaryColor,
      Value<int> secondaryColor,
      Value<int> headerColor,
      Value<int> photoBackground,
      Value<String> divisionColors,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$SchoolConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $SchoolConfigsTable> {
  $$SchoolConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressLine => $composableBuilder(
    column: $table.addressLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactLine => $composableBuilder(
    column: $table.contactLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localLogoPath => $composableBuilder(
    column: $table.localLogoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get principalSignatureUrl => $composableBuilder(
    column: $table.principalSignatureUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPrincipalSignaturePath => $composableBuilder(
    column: $table.localPrincipalSignaturePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardSizeId => $composableBuilder(
    column: $table.cardSizeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledFields => $composableBuilder(
    column: $table.enabledFields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get headerColor => $composableBuilder(
    column: $table.headerColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoBackground => $composableBuilder(
    column: $table.photoBackground,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get divisionColors => $composableBuilder(
    column: $table.divisionColors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchoolConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $SchoolConfigsTable> {
  $$SchoolConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressLine => $composableBuilder(
    column: $table.addressLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactLine => $composableBuilder(
    column: $table.contactLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localLogoPath => $composableBuilder(
    column: $table.localLogoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get principalSignatureUrl => $composableBuilder(
    column: $table.principalSignatureUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPrincipalSignaturePath => $composableBuilder(
    column: $table.localPrincipalSignaturePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardSizeId => $composableBuilder(
    column: $table.cardSizeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledFields => $composableBuilder(
    column: $table.enabledFields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get headerColor => $composableBuilder(
    column: $table.headerColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoBackground => $composableBuilder(
    column: $table.photoBackground,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get divisionColors => $composableBuilder(
    column: $table.divisionColors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchoolConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchoolConfigsTable> {
  $$SchoolConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get addressLine => $composableBuilder(
    column: $table.addressLine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactLine => $composableBuilder(
    column: $table.contactLine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get localLogoPath => $composableBuilder(
    column: $table.localLogoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get principalSignatureUrl => $composableBuilder(
    column: $table.principalSignatureUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPrincipalSignaturePath => $composableBuilder(
    column: $table.localPrincipalSignaturePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardSizeId => $composableBuilder(
    column: $table.cardSizeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enabledFields => $composableBuilder(
    column: $table.enabledFields,
    builder: (column) => column,
  );

  GeneratedColumn<int> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get headerColor => $composableBuilder(
    column: $table.headerColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get photoBackground => $composableBuilder(
    column: $table.photoBackground,
    builder: (column) => column,
  );

  GeneratedColumn<String> get divisionColors => $composableBuilder(
    column: $table.divisionColors,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SchoolConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SchoolConfigsTable,
          SchoolConfigRow,
          $$SchoolConfigsTableFilterComposer,
          $$SchoolConfigsTableOrderingComposer,
          $$SchoolConfigsTableAnnotationComposer,
          $$SchoolConfigsTableCreateCompanionBuilder,
          $$SchoolConfigsTableUpdateCompanionBuilder,
          (
            SchoolConfigRow,
            BaseReferences<_$AppDatabase, $SchoolConfigsTable, SchoolConfigRow>,
          ),
          SchoolConfigRow,
          PrefetchHooks Function()
        > {
  $$SchoolConfigsTableTableManager(_$AppDatabase db, $SchoolConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchoolConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchoolConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchoolConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> addressLine = const Value.absent(),
                Value<String> contactLine = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> localLogoPath = const Value.absent(),
                Value<String?> principalSignatureUrl = const Value.absent(),
                Value<String?> localPrincipalSignaturePath =
                    const Value.absent(),
                Value<String> cardSizeId = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> enabledFields = const Value.absent(),
                Value<int> primaryColor = const Value.absent(),
                Value<int> secondaryColor = const Value.absent(),
                Value<int> headerColor = const Value.absent(),
                Value<int> photoBackground = const Value.absent(),
                Value<String> divisionColors = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchoolConfigsCompanion(
                id: id,
                name: name,
                addressLine: addressLine,
                contactLine: contactLine,
                logoUrl: logoUrl,
                localLogoPath: localLogoPath,
                principalSignatureUrl: principalSignatureUrl,
                localPrincipalSignaturePath: localPrincipalSignaturePath,
                cardSizeId: cardSizeId,
                templateId: templateId,
                enabledFields: enabledFields,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                headerColor: headerColor,
                photoBackground: photoBackground,
                divisionColors: divisionColors,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> addressLine = const Value.absent(),
                Value<String> contactLine = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> localLogoPath = const Value.absent(),
                Value<String?> principalSignatureUrl = const Value.absent(),
                Value<String?> localPrincipalSignaturePath =
                    const Value.absent(),
                Value<String> cardSizeId = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> enabledFields = const Value.absent(),
                Value<int> primaryColor = const Value.absent(),
                Value<int> secondaryColor = const Value.absent(),
                Value<int> headerColor = const Value.absent(),
                Value<int> photoBackground = const Value.absent(),
                Value<String> divisionColors = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchoolConfigsCompanion.insert(
                id: id,
                name: name,
                addressLine: addressLine,
                contactLine: contactLine,
                logoUrl: logoUrl,
                localLogoPath: localLogoPath,
                principalSignatureUrl: principalSignatureUrl,
                localPrincipalSignaturePath: localPrincipalSignaturePath,
                cardSizeId: cardSizeId,
                templateId: templateId,
                enabledFields: enabledFields,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                headerColor: headerColor,
                photoBackground: photoBackground,
                divisionColors: divisionColors,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SchoolConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SchoolConfigsTable,
      SchoolConfigRow,
      $$SchoolConfigsTableFilterComposer,
      $$SchoolConfigsTableOrderingComposer,
      $$SchoolConfigsTableAnnotationComposer,
      $$SchoolConfigsTableCreateCompanionBuilder,
      $$SchoolConfigsTableUpdateCompanionBuilder,
      (
        SchoolConfigRow,
        BaseReferences<_$AppDatabase, $SchoolConfigsTable, SchoolConfigRow>,
      ),
      SchoolConfigRow,
      PrefetchHooks Function()
    >;
typedef $$AuditLogsTableCreateCompanionBuilder = AuditLogsCompanion Function({
  Value<int> id,
  required String action,
  required String entityType,
  required String entityId,
  required String actorUid,
  Value<String> details,
  required DateTime createdAt,
});
typedef $$AuditLogsTableUpdateCompanionBuilder = AuditLogsCompanion Function({
  Value<int> id,
  Value<String> action,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> actorUid,
  Value<String> details,
  Value<DateTime> createdAt,
});

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUid => $composableBuilder(
    column: $table.actorUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get actorUid =>
      $composableBuilder(column: $table.actorUid, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLogRow,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (
            AuditLogRow,
            BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLogRow>,
          ),
          AuditLogRow,
          PrefetchHooks Function()
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> actorUid = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                action: action,
                entityType: entityType,
                entityId: entityId,
                actorUid: actorUid,
                details: details,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String action,
                required String entityType,
                required String entityId,
                required String actorUid,
                Value<String> details = const Value.absent(),
                required DateTime createdAt,
              }) => AuditLogsCompanion.insert(
                id: id,
                action: action,
                entityType: entityType,
                entityId: entityId,
                actorUid: actorUid,
                details: details,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLogRow,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (
        AuditLogRow,
        BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLogRow>,
      ),
      AuditLogRow,
      PrefetchHooks Function()
    >;
typedef $$PrintBatchesTableCreateCompanionBuilder =
    PrintBatchesCompanion Function({
      required String id,
      required String schoolId,
      required int cardCount,
      required String sheetType,
      required int sheetCount,
      required String generatedBy,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PrintBatchesTableUpdateCompanionBuilder =
    PrintBatchesCompanion Function({
      Value<String> id,
      Value<String> schoolId,
      Value<int> cardCount,
      Value<String> sheetType,
      Value<int> sheetCount,
      Value<String> generatedBy,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PrintBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $PrintBatchesTable> {
  $$PrintBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardCount => $composableBuilder(
    column: $table.cardCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sheetType => $composableBuilder(
    column: $table.sheetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sheetCount => $composableBuilder(
    column: $table.sheetCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generatedBy => $composableBuilder(
    column: $table.generatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrintBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $PrintBatchesTable> {
  $$PrintBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardCount => $composableBuilder(
    column: $table.cardCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sheetType => $composableBuilder(
    column: $table.sheetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sheetCount => $composableBuilder(
    column: $table.sheetCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generatedBy => $composableBuilder(
    column: $table.generatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrintBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrintBatchesTable> {
  $$PrintBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<int> get cardCount =>
      $composableBuilder(column: $table.cardCount, builder: (column) => column);

  GeneratedColumn<String> get sheetType =>
      $composableBuilder(column: $table.sheetType, builder: (column) => column);

  GeneratedColumn<int> get sheetCount => $composableBuilder(
    column: $table.sheetCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get generatedBy => $composableBuilder(
    column: $table.generatedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PrintBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrintBatchesTable,
          PrintBatchRow,
          $$PrintBatchesTableFilterComposer,
          $$PrintBatchesTableOrderingComposer,
          $$PrintBatchesTableAnnotationComposer,
          $$PrintBatchesTableCreateCompanionBuilder,
          $$PrintBatchesTableUpdateCompanionBuilder,
          (
            PrintBatchRow,
            BaseReferences<_$AppDatabase, $PrintBatchesTable, PrintBatchRow>,
          ),
          PrintBatchRow,
          PrefetchHooks Function()
        > {
  $$PrintBatchesTableTableManager(_$AppDatabase db, $PrintBatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrintBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrintBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrintBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<int> cardCount = const Value.absent(),
                Value<String> sheetType = const Value.absent(),
                Value<int> sheetCount = const Value.absent(),
                Value<String> generatedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrintBatchesCompanion(
                id: id,
                schoolId: schoolId,
                cardCount: cardCount,
                sheetType: sheetType,
                sheetCount: sheetCount,
                generatedBy: generatedBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String schoolId,
                required int cardCount,
                required String sheetType,
                required int sheetCount,
                required String generatedBy,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PrintBatchesCompanion.insert(
                id: id,
                schoolId: schoolId,
                cardCount: cardCount,
                sheetType: sheetType,
                sheetCount: sheetCount,
                generatedBy: generatedBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrintBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrintBatchesTable,
      PrintBatchRow,
      $$PrintBatchesTableFilterComposer,
      $$PrintBatchesTableOrderingComposer,
      $$PrintBatchesTableAnnotationComposer,
      $$PrintBatchesTableCreateCompanionBuilder,
      $$PrintBatchesTableUpdateCompanionBuilder,
      (
        PrintBatchRow,
        BaseReferences<_$AppDatabase, $PrintBatchesTable, PrintBatchRow>,
      ),
      PrintBatchRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StudentEntriesTableTableManager get studentEntries =>
      $$StudentEntriesTableTableManager(_db, _db.studentEntries);
  $$SchoolConfigsTableTableManager get schoolConfigs =>
      $$SchoolConfigsTableTableManager(_db, _db.schoolConfigs);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$PrintBatchesTableTableManager get printBatches =>
      $$PrintBatchesTableTableManager(_db, _db.printBatches);
}
