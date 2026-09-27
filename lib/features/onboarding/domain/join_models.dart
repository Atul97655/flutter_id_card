/// The states a teacher passes through between installing the app and being
/// able to submit a card.
///
/// There are only three, and naming them is most of the point. Screen 18
/// exists because a teacher who lands on a greyed-out home screen rings the
/// office to ask whether the app is broken; a state with a name and a
/// sentence saying who resolves it removes that call.
library;

/// Where a teacher stands with a school.
enum JoinStatus {
  /// Scanned a code, waiting for the office to assign a class.
  pending,

  /// The office has assigned a class. The teacher can work.
  active,

  /// The office declined. Not a ban - they may scan again.
  declined;

  /// Unknown values read as [pending], the state that grants nothing.
  ///
  /// A status written by a newer build must never read here as approved:
  /// the failure direction has to be towards less access, not more.
  static JoinStatus fromWire(String? value) {
    for (final JoinStatus s in JoinStatus.values) {
      if (s.name == value) return s;
    }
    return JoinStatus.pending;
  }
}

/// A school, as a teacher sees it before they have any right to it.
///
/// Resolved from `joinCodes/{token}`, which carries the school's id and name
/// and nothing else. That is deliberately the least that makes screen 17
/// honest - the teacher is asked to confirm a school, so they have to be told
/// which school, and being told the name is not the same as being let in.
class SchoolInvitation {
  const SchoolInvitation({
    required this.token,
    required this.schoolId,
    required this.schoolName,
  });

  final String token;
  final String schoolId;
  final String schoolName;

  static SchoolInvitation? fromWire(String token, Map<String, Object?>? data) {
    if (data == null) return null;
    final Object? schoolId = data['schoolId'];
    if (schoolId is! String || schoolId.isEmpty) return null;
    final Object? name = data['schoolName'];
    return SchoolInvitation(
      token: token,
      schoolId: schoolId,
      schoolName: name is String ? name : '',
    );
  }
}

/// What the app knows about this teacher's place in a school.
class JoinState {
  const JoinState({
    required this.status,
    this.schoolId = '',
    this.schoolName = '',
    this.classLevel = '',
    this.division = '',
  });

  /// Nothing scanned, nothing assigned.
  static const JoinState none = JoinState(status: JoinStatus.declined);

  final JoinStatus status;
  final String schoolId;
  final String schoolName;
  final String classLevel;
  final String division;

  /// Whether the office has finished with this teacher and they may work.
  ///
  /// Requires the class AND the section, not just the status. An assignment
  /// half-written is not an assignment, and letting someone through on one
  /// would put them in a school with no section - which the rules read as
  /// the whole school.
  bool get isReady =>
      status == JoinStatus.active &&
      schoolId.isNotEmpty &&
      classLevel.isNotEmpty &&
      division.isNotEmpty;

  /// "10 - A", for the chip on the scoped home screen.
  String get sectionLabel =>
      classLevel.isEmpty || division.isEmpty ? '' : '$classLevel - $division';
}

/// Why a scan did not work, in words a teacher can act on.
///
/// "Invalid QR code" is not one of them. A teacher holding a poster that
/// worked last week needs to be told the code was replaced and to ask the
/// office for the new one - anything less sends them to the office to report
/// a broken app instead.
enum ScanFailure {
  /// The QR resolved to nothing. Almost always a rotated code.
  unknownCode,

  /// Scanned something that is not one of our codes at all.
  notOurCode,

  /// Network, permissions, or Firestore said no.
  couldNotReach;

  String get message => switch (this) {
    ScanFailure.unknownCode =>
      'This code is no longer in use. Your school office has issued a new '
          'one - ask them for the current code sheet.',
    ScanFailure.notOurCode =>
      'That is not a school code. Scan the code your school office gave '
          'you.',
    ScanFailure.couldNotReach =>
      'Could not reach the office. Check your connection and try again.',
  };
}
