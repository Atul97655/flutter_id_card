import 'package:flutter_id_card/shared/services/local/app_database.dart';
import 'package:flutter_id_card/shared/services/local/school_repository.dart';
import 'package:flutter_id_card/shared/services/local/student_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single database handle for the process.
///
/// Overridden in tests with `AppDatabase.forTesting(NativeDatabase.memory())`.
/// `keepAlive` matters here: letting Riverpod dispose this would close the
/// SQLite connection out from under any in-flight write.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) {
    final AppDatabase db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
);

final Provider<StudentRepository> studentRepositoryProvider = Provider<StudentRepository>(
  (Ref ref) => StudentRepository(ref.watch(appDatabaseProvider)),
);

final Provider<SchoolRepository> schoolRepositoryProvider = Provider<SchoolRepository>(
  (Ref ref) => SchoolRepository(ref.watch(appDatabaseProvider)),
);
