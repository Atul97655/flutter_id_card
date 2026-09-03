import 'package:flutter_id_card/shared/models/student_field.dart';

/// Form validation rules.
///
/// Every function returns `null` when valid and an operator-facing message when
/// not, matching Flutter's `FormFieldValidator` contract. Kept free of Flutter
/// imports so they can be unit-tested without a widget binding.
final class Validators {
  const Validators._();

  /// Indian mobile numbers are exactly 10 digits.
  static const int mobileLength = 10;

  /// Nobody carrying a school ID card was born before this. Guards against a
  /// mistyped year (e.g. 1015 for 2015) producing an absurd card.
  static const int maxAgeYears = 100;

  /// Address is printed at 5 pt across at most two lines. Beyond this it will
  /// ellipsise, so we stop the operator at entry time rather than silently
  /// truncating something important on the printed card.
  static const int addressMaxLength = 120;

  static const int nameMaxLength = 40;

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? name(String? value, {String label = 'Name'}) {
    final String? empty = required(value, label);
    if (empty != null) return empty;

    final String trimmed = value!.trim();
    if (trimmed.length < 2) return '$label is too short';
    if (trimmed.length > nameMaxLength) {
      return '$label must be $nameMaxLength characters or fewer';
    }
    return null;
  }

  /// A short identifier field: Class, Div, roll number and the like.
  ///
  /// Unlike [name], a single character is valid here - "A", "B", "1" are
  /// completely normal divisions and classes, not typos. The div-badge card
  /// template in particular is built around single-letter divisions (A-F), so
  /// rejecting them as "too short" would make that template unusable.
  static String? shortCode(String? value, {String label = 'Value'}) {
    final String? empty = required(value, label);
    if (empty != null) return empty;

    final String trimmed = value!.trim();
    if (trimmed.length > nameMaxLength) {
      return '$label must be $nameMaxLength characters or fewer';
    }
    return null;
  }

  static String? mobile(String? value, {bool isRequired = true}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? 'Mobile No is required' : null;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      return 'Mobile No must contain digits only';
    }
    if (trimmed.length != mobileLength) {
      return 'Mobile No must be exactly $mobileLength digits';
    }
    return null;
  }

  static String? bloodGroup(String? value, {bool isRequired = true}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? 'Blood Group is required' : null;
    }
    if (!kBloodGroups.contains(trimmed)) {
      return 'Select a valid blood group';
    }
    return null;
  }

  static String? address(String? value, {bool isRequired = true}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? 'Address is required' : null;
    }
    if (trimmed.length > addressMaxLength) {
      return 'Address must be $addressMaxLength characters or fewer '
          '(it prints on 2 lines)';
    }
    return null;
  }

  /// DOB must be a real date in the past and within a plausible age range.
  ///
  /// [now] is injectable so the test suite is not time-dependent.
  static String? dateOfBirth(DateTime? value, {bool isRequired = true, DateTime? now}) {
    if (value == null) {
      return isRequired ? 'DOB is required' : null;
    }
    final DateTime today = now ?? DateTime.now();
    final DateTime todayMidnight = DateTime(today.year, today.month, today.day);
    final DateTime dobMidnight = DateTime(value.year, value.month, value.day);

    if (!dobMidnight.isBefore(todayMidnight)) {
      return 'DOB must be in the past';
    }
    final DateTime earliest = DateTime(today.year - maxAgeYears, today.month, today.day);
    if (dobMidnight.isBefore(earliest)) {
      return 'DOB looks wrong - check the year';
    }
    return null;
  }

  /// Generic dispatcher used by the dynamic form builder so it does not need a
  /// switch of its own. [isRequired] comes from the school's field config.
  static String? forField(
    StudentField field,
    String? value, {
    bool isRequired = true,
    DateTime? parsedDate,
    DateTime? now,
  }) {
    if (!isRequired && (value == null || value.trim().isEmpty)) return null;

    // Class and Div are short-code fields (single letters/digits are valid),
    // not person-name fields - see [shortCode]. Everything else that carries
    // FieldKind.text is an actual name (student, father) and keeps the
    // stricter [name] check.
    if (field == StudentField.studentClass || field == StudentField.division) {
      return shortCode(value, label: field.formLabel);
    }

    return switch (field.kind) {
      FieldKind.mobile => mobile(value, isRequired: isRequired),
      FieldKind.bloodGroup => bloodGroup(value, isRequired: isRequired),
      FieldKind.date => dateOfBirth(parsedDate, isRequired: isRequired, now: now),
      FieldKind.multiline => address(value, isRequired: isRequired),
      FieldKind.text => name(value, label: field.formLabel),
      FieldKind.photo => null,
    };
  }
}
