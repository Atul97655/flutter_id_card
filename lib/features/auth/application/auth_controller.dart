import 'package:flutter_id_card/features/auth/data/auth_repository.dart';
import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_id_card/shared/providers/core_providers.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => AuthRepository());

/// Owns the signed-in session for the whole app.
///
/// `null` data means "signed out"; an error state means the last sign-in
/// attempt failed and the message should be shown on the login form.
class AuthController extends AsyncNotifier<SessionUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<SessionUser?> build() => _repo.restoreSession();

  Future<bool> signInAsSchool({
    required String schoolCode,
    required String password,
  }) async {
    return _attempt(
      () => _repo.signInAsSchool(schoolCode: schoolCode, password: password),
    );
  }

  Future<bool> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    return _attempt(
      () => _repo.signInAsAdmin(email: email, password: password),
    );
  }

  /// Debug-only local session so the data-entry, photo and print pipeline can
  /// be exercised before Firebase credentials are wired up. Guarded at the call
  /// site by `kDebugMode`; entries created under it are never synced.
  ///
  /// Re-seeds the demo school on every debug login, unconditionally.
  ///
  /// It used to seed only when the school didn't already exist, which meant a
  /// device's first-ever debug login froze it onto whatever demo config
  /// existed at the time - a later template/colour change made here would
  /// silently never reach a device that had already run it once. There is no
  /// admin UI yet to change these settings by hand, so "edit the seed, log in
  /// again" needs to actually work.
  ///
  /// Currently seeded as the Sacred Heart Convent reference design
  /// (`div_badge_vertical`), the one built around per-division colours - the
  /// most visually distinctive of the five shipped templates. Type a Division
  /// of A/B/C/D/E/F on a new entry to see its accent colour switch live.
  Future<void> startOfflineTestSession({required String schoolId}) async {
    final SchoolRepository schools = ref.read(schoolRepositoryProvider);
    await schools.save(
      SchoolConfig(
        id: schoolId,
        name: 'SACRED HEART CONVENT',
        addressLine: 'PRE-PRIMARY SCHOOL, KESHWAPUR HUBBALLI',
        contactLine: 'Mob: 9538848187',
        templateId: 'div_badge_vertical',
        divisionColors: const <String, int>{
          'A': 0xFFE01B1B, // red
          'B': 0xFF1A1AE0, // blue
          'C': 0xFFE0189C, // pink
          'D': 0xFF14A05A, // green
          'E': 0xFFF07A16, // orange
          'F': 0xFF7B1FA2, // purple
        },
        // Only the fields this template actually has a slot for - the rest
        // stay off so a full-field entry doesn't trigger a fit warning here.
        enabledFieldKeys: const <String>{'name', 'photo', 'division', 'mobile', 'address'},
        updatedAt: DateTime.now(),
      ),
    );

    state = AsyncValue<SessionUser?>.data(
      SessionUser(
        uid: 'offline-test',
        email: 'offline@test.local',
        role: UserRole.school,
        schoolId: schoolId,
        displayName: 'Offline Test',
        isOfflineTestSession: true,
      ),
    );
  }

  /// Returns whether the attempt succeeded, so the form can decide to navigate
  /// without having to re-read and interpret the async state.
  Future<bool> _attempt(Future<SessionUser> Function() action) async {
    state = const AsyncValue<SessionUser?>.loading();
    final AsyncValue<SessionUser?> result =
        await AsyncValue.guard<SessionUser?>(action);
    state = result;
    return result.hasValue && result.value != null;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue<SessionUser?>.data(null);
  }

  /// Clears a stale error so the login form's message disappears as soon as the
  /// operator starts correcting their input.
  void clearError() {
    if (state.hasError) {
      state = const AsyncValue<SessionUser?>.data(null);
    }
  }
}

final AsyncNotifierProvider<AuthController, SessionUser?> authControllerProvider =
    AsyncNotifierProvider<AuthController, SessionUser?>(AuthController.new);

/// The signed-in user, or null while loading / signed out. Convenience for the
/// many widgets that only care about the happy path.
final Provider<SessionUser?> currentSessionProvider = Provider<SessionUser?>(
  (Ref ref) => ref.watch(authControllerProvider).value,
);

/// The school whose data the current screen operates on. For an operator this
/// is fixed by their account; admins select one in the dashboard.
final NotifierProvider<ActiveSchoolController, String?> activeSchoolIdProvider =
    NotifierProvider<ActiveSchoolController, String?>(ActiveSchoolController.new);

class ActiveSchoolController extends Notifier<String?> {
  @override
  String? build() {
    // Follows the session for operators; admins override it explicitly.
    final SessionUser? session = ref.watch(currentSessionProvider);
    if (session == null) return null;
    return session.isAdmin ? _adminSelection : session.schoolId;
  }

  String? _adminSelection;

  void select(String? schoolId) {
    _adminSelection = schoolId;
    state = schoolId;
  }
}
