import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A half-finished data-entry form, kept so it survives the app being
/// backgrounded or killed.
///
/// Android will happily kill a backgrounded app to reclaim memory, and an
/// operator working through a classroom gets phone calls. Without this, a form
/// filled in but not yet saved is simply gone, and the student has to be found
/// and re-interviewed. That is the failure this exists to prevent.
///
/// Deliberately **not** in the Drift database: a draft is scratch state, not a
/// record. Putting it in the entries table would mean half-typed rows showing
/// up in Saved Entries and the sync queue, which is worse than losing them.
class EntryDraft {
  const EntryDraft({
    required this.schoolId,
    this.entryId,
    this.name = '',
    this.fatherName = '',
    this.studentClass = '',
    this.division = '',
    this.bloodGroup = '',
    this.dobIso,
    this.mobile = '',
    this.address = '',
    this.photoPath,
    this.savedAt,
  });

  final String schoolId;

  /// Set when editing an existing entry, so a restored draft is applied to the
  /// right record rather than creating a duplicate.
  final String? entryId;

  final String name;
  final String fatherName;
  final String studentClass;
  final String division;
  final String bloodGroup;
  final String? dobIso;
  final String mobile;
  final String address;
  final String? photoPath;

  final DateTime? savedAt;

  /// Whether there is anything worth restoring. An empty draft should never
  /// prompt the operator.
  bool get hasContent =>
      name.trim().isNotEmpty ||
      fatherName.trim().isNotEmpty ||
      studentClass.trim().isNotEmpty ||
      division.trim().isNotEmpty ||
      bloodGroup.trim().isNotEmpty ||
      mobile.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      dobIso != null ||
      (photoPath?.isNotEmpty ?? false);

  Map<String, Object?> toJson() => <String, Object?>{
        'schoolId': schoolId,
        'entryId': entryId,
        'name': name,
        'fatherName': fatherName,
        'studentClass': studentClass,
        'division': division,
        'bloodGroup': bloodGroup,
        'dobIso': dobIso,
        'mobile': mobile,
        'address': address,
        'photoPath': photoPath,
        'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
      };

  static EntryDraft fromJson(Map<String, Object?> json) => EntryDraft(
        schoolId: (json['schoolId'] as String?) ?? '',
        entryId: json['entryId'] as String?,
        name: (json['name'] as String?) ?? '',
        fatherName: (json['fatherName'] as String?) ?? '',
        studentClass: (json['studentClass'] as String?) ?? '',
        division: (json['division'] as String?) ?? '',
        bloodGroup: (json['bloodGroup'] as String?) ?? '',
        dobIso: json['dobIso'] as String?,
        mobile: (json['mobile'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        photoPath: json['photoPath'] as String?,
        savedAt: DateTime.tryParse((json['savedAt'] as String?) ?? ''),
      );
}

/// Persists the in-progress form.
///
/// Exactly one draft is kept. An operator only fills one form at a time, and a
/// queue of stale drafts would be a worse problem than the one being solved.
class DraftStore {
  const DraftStore();

  static const String _key = 'entry_draft';

  /// Drafts older than this are discarded rather than offered. Restoring
  /// yesterday's half-typed student into today's session would be confusing
  /// and probably wrong.
  static const Duration maxAge = Duration(hours: 12);

  Future<void> save(EntryDraft draft) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(draft.toJson()));
    } on Object catch (e) {
      // Autosave is a safety net; failing to write it must never interrupt the
      // operator mid-form.
      if (kDebugMode) debugPrint('Draft save failed: $e');
    }
  }

  /// Returns a usable draft for [schoolId], or null.
  ///
  /// Filters by school so a draft captured under one login is never offered
  /// after signing in as a different school.
  Future<EntryDraft?> load(String schoolId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;

      final EntryDraft draft = EntryDraft.fromJson(decoded);

      if (draft.schoolId != schoolId) return null;
      if (!draft.hasContent) return null;

      final DateTime? at = draft.savedAt;
      if (at != null && DateTime.now().difference(at) > maxAge) {
        await clear();
        return null;
      }

      return draft;
    } on Object {
      // A corrupt draft is not worth surfacing - drop it and move on.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object {
      // Nothing useful to do; a stale draft ages out on its own.
    }
  }
}
