import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_id_card/features/auth/application/auth_controller.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/models/student_entry.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/firebase/firebase_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every school a parent can send a card to.
///
/// Read from Firestore when it can be, because a school the office added this
/// morning should be pickable this morning. Falls back to the copies already
/// cached on the device (from earlier picks and from sync) so the list is not
/// empty on a bad connection. The rules let a parent read school documents
/// for exactly this purpose.
// Type is inferred: Riverpod 3 keeps the auto-dispose provider classes out of
// its public API, so there is nothing stable to annotate with here.
final schoolDirectoryProvider =
    FutureProvider.autoDispose<List<SchoolConfig>>((Ref ref) async {
      final List<SchoolConfig> cached = await ref
          .read(schoolRepositoryProvider)
          .listAll();

      if (!FirebaseBootstrap.instance.isReady) return cached;

      try {
        final QuerySnapshot<Map<String, Object?>> snap = await FirebaseFirestore
            .instance
            .collection('schools')
            .get();
        final List<SchoolConfig> remote = <SchoolConfig>[
          for (final QueryDocumentSnapshot<Map<String, Object?>> d
              in snap.docs)
            SchoolConfig.fromFirestoreMap(d.id, d.data()),
        ]..sort((SchoolConfig a, SchoolConfig b) => a.name.compareTo(b.name));
        return remote.isEmpty ? cached : remote;
      } on Object catch (e) {
        if (kDebugMode) debugPrint('School directory fetch failed: $e');
        return cached;
      }
    });

/// The cards this parent has submitted, across every school, newest first.
///
/// Filtered by the submitting account, not by school: unlike an operator, a
/// parent has no single active school to scope the list to. Reads the local
/// database, which sync keeps in step with the office's decisions.
final StreamProvider<List<StudentEntry>> parentEntriesProvider =
    StreamProvider<List<StudentEntry>>((Ref ref) {
      final SessionUser? session = ref.watch(currentSessionProvider);
      if (session == null) {
        return Stream<List<StudentEntry>>.value(const <StudentEntry>[]);
      }
      return ref.watch(studentRepositoryProvider).watchAll().map(
        (List<StudentEntry> all) => all
            .where((StudentEntry e) => e.submittedByUid == session.uid)
            .toList(),
      );
    });

/// School id -> name, from the local cache, for labelling the list above.
final StreamProvider<Map<String, String>> schoolNamesProvider =
    StreamProvider<Map<String, String>>((Ref ref) {
      return ref.watch(schoolRepositoryProvider).watchAll().map(
        (List<SchoolConfig> all) => <String, String>{
          for (final SchoolConfig s in all) s.id: s.name,
        },
      );
    });
