import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_result.dart';
import '../../data/datasources/local_storage_datasource.dart';
import '../../data/repositories/storage_repository_impl.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/usecases/delete_session_usecase.dart';
import '../../domain/usecases/get_sessions_usecase.dart';
import '../../domain/usecases/save_session_usecase.dart';
import '../../domain/usecases/save_shot_usecase.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final localStorageDatasourceProvider = Provider<LocalStorageDatasource>(
  (ref) => const LocalStorageDatasource(),
);

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepositoryImpl(ref.watch(localStorageDatasourceProvider)),
);

// ── Use-case providers ────────────────────────────────────────────────────────

final getSessionsUseCaseProvider = Provider<GetSessionsUseCase>(
  (ref) => GetSessionsUseCase(ref.watch(storageRepositoryProvider)),
);

final saveSessionUseCaseProvider = Provider<SaveSessionUseCase>(
  (ref) => SaveSessionUseCase(ref.watch(storageRepositoryProvider)),
);

final deleteSessionUseCaseProvider = Provider<DeleteSessionUseCase>(
  (ref) => DeleteSessionUseCase(ref.watch(storageRepositoryProvider)),
);

final saveShotUseCaseProvider = Provider<SaveShotUseCase>(
  (ref) => SaveShotUseCase(ref.watch(storageRepositoryProvider)),
);

// ── Session list notifier ─────────────────────────────────────────────────────

class SessionListNotifier extends AsyncNotifier<List<Session>> {
  @override
  Future<List<Session>> build() => _fetchSessions();

  Future<List<Session>> _fetchSessions() async {
    final result = await ref.read(getSessionsUseCaseProvider)();
    return result.when(
      onSuccess: (sessions) => sessions,
      onFailure: (f) => throw Exception(f.message),
    );
  }

  Future<Result<String>> addSession(Session session) async {
    final result = await ref.read(saveSessionUseCaseProvider)(session);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> removeSession(String sessionId) async {
    final result = await ref.read(deleteSessionUseCaseProvider)(sessionId);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<String>> addShot(ShotResult shot) async {
    final result = await ref.read(saveShotUseCaseProvider)(shot);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }
}

final sessionListProvider =
    AsyncNotifierProvider<SessionListNotifier, List<Session>>(
  SessionListNotifier.new,
);

// ── Single session provider ───────────────────────────────────────────────────

final sessionByIdProvider =
    FutureProvider.family<Session?, String>((ref, id) async {
  final sessions = await ref.watch(sessionListProvider.future);
  try {
    return sessions.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});
