import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';

/// Represents a user account managed by the organisation (Admin or School Operator).
class ManagedUser {
  const ManagedUser({
    required this.uid,
    required this.email,
    required this.role,
    this.schoolId,
    this.displayName = '',
    this.active = true,
    this.lastLoginDate,
    this.createdAt,
  });

  final String uid;
  final String email;
  final UserRole role;
  final String? schoolId;
  final String displayName;
  final bool active;
  final DateTime? lastLoginDate;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  Map<String, Object?> toFirestoreMap() => <String, Object?>{
        'email': email,
        'role': role.wireValue,
        'schoolId': schoolId,
        'displayName': displayName,
        'active': active,
        if (lastLoginDate != null)
          'lastLoginDate': Timestamp.fromDate(lastLoginDate!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  Map<String, Object?> toJson() => <String, Object?>{
        'uid': uid,
        'email': email,
        'role': role.wireValue,
        'schoolId': schoolId,
        'displayName': displayName,
        'active': active,
        'lastLoginDate': lastLoginDate?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };

  static ManagedUser fromFirestore(String uid, Map<String, Object?> data) {
    DateTime? parseDate(Object? val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ManagedUser(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      role: UserRole.fromWire(data['role'] as String?),
      schoolId: data['schoolId'] as String?,
      displayName: (data['displayName'] as String?) ?? '',
      active: data['active'] != false,
      lastLoginDate: parseDate(data['lastLoginDate']),
      createdAt: parseDate(data['createdAt']),
    );
  }

  static ManagedUser fromJson(Map<String, Object?> json) => ManagedUser(
        uid: (json['uid'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        role: UserRole.fromWire(json['role'] as String?),
        schoolId: json['schoolId'] as String?,
        displayName: (json['displayName'] as String?) ?? '',
        active: json['active'] != false,
        lastLoginDate: DateTime.tryParse((json['lastLoginDate'] as String?) ?? ''),
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
      );

  ManagedUser copyWith({
    String? uid,
    String? email,
    UserRole? role,
    String? schoolId,
    String? displayName,
    bool? active,
    DateTime? lastLoginDate,
    DateTime? createdAt,
  }) {
    return ManagedUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      displayName: displayName ?? this.displayName,
      active: active ?? this.active,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ManagedUser($email, ${role.wireValue}, active=$active)';
}
