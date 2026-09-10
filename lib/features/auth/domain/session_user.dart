/// Who is signed in, and what they are allowed to do.
///
/// Roles are resolved from the `users/{uid}` Firestore document, never from
/// anything the client can set. The admin screens are gated on
/// [SessionUser.isAdmin]; the Firestore security rules enforce the same check
/// server-side, because a client-side role check alone is decoration.
enum UserRole {
  admin('Admin'),

  /// An individual teacher submitting cards for their school. Same data scope
  /// as [school] - both are tied to one `schoolId` and see only that school's
  /// students. The distinction is organisational, not a privilege boundary:
  /// a school account is the office, a teacher account is one person in it.
  teacher('Teacher'),

  school('School');

  const UserRole(this.wireValue);

  /// Exact string stored in Firestore. Matches the values already in the
  /// project's `users` collection.
  final String wireValue;

  /// Everyone who is not an admin: submits cards, sees only their own school,
  /// and can message only the admin.
  bool get isOperator => this != UserRole.admin;

  static UserRole fromWire(String? value) {
    for (final UserRole r in UserRole.values) {
      if (r.wireValue.toLowerCase() == (value ?? '').trim().toLowerCase()) {
        return r;
      }
    }
    // Least-privilege default: an unrecognised role gets school access, never
    // admin access.
    return UserRole.school;
  }
}

class SessionUser {
  const SessionUser({
    required this.uid,
    required this.email,
    required this.role,
    this.schoolId,
    this.displayName = '',
    this.isOfflineTestSession = false,
  });

  final String uid;
  final String email;
  final UserRole role;

  /// Which school this operator enters data for. Null for admins, who work
  /// across all schools.
  final String? schoolId;

  final String displayName;

  /// True only for the debug-build local session. Sync is disabled for these
  /// so test data can never reach the production Firestore.
  final bool isOfflineTestSession;

  bool get isAdmin => role == UserRole.admin;

  /// The school an operator's work is filed under. Admins pick a school
  /// explicitly in the dashboard, so this is only meaningful for operators.
  bool get canEnterData => schoolId != null && schoolId!.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'uid': uid,
        'email': email,
        'role': role.wireValue,
        'schoolId': schoolId,
        'displayName': displayName,
      };

  static SessionUser fromJson(Map<String, Object?> json) => SessionUser(
        uid: (json['uid'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        role: UserRole.fromWire(json['role'] as String?),
        schoolId: json['schoolId'] as String?,
        displayName: (json['displayName'] as String?) ?? '',
      );

  @override
  String toString() => 'SessionUser($email, ${role.wireValue}, school=$schoolId)';
}

/// Raised for anything the operator needs to read and act on. Firebase's raw
/// exception codes are useless on a shop floor, so they are translated here.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
