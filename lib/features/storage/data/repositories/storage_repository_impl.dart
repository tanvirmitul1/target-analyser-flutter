import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_result.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/storage_repository.dart';
import '../datasources/local_storage_datasource.dart';
import '../models/session_model.dart';
import '../models/shot_model.dart';

/// Bridges the domain and data layers; wraps every call with [guard].
class StorageRepositoryImpl implements StorageRepository {
  const StorageRepositoryImpl(this._datasource);
  final LocalStorageDatasource _datasource;

  // ── Sessions ───────────────────────────────────────────────────────────────

  @override
  Future<Result<List<Session>>> getSessions() => guard(
        () async {
          final models = await _datasource.getSessions();
          final sessions = <Session>[];
          for (final m in models) {
            final shots = await _datasource.getShotsForSession(m.id);
            sessions.add(m.toDomain(shots: shots.map((s) => s.toDomain()).toList()));
          }
          return sessions;
        },
        onError: (e, st) => DatabaseFailure('Failed to load sessions.', cause: e),
      );

  @override
  Future<Result<Session>> getSessionById(String id) => guard(
        () async {
          final model = await _datasource.getSessionById(id);
          if (model == null) {
            throw StateError('Session $id not found.');
          }
          final shots = await _datasource.getShotsForSession(id);
          return model.toDomain(shots: shots.map((s) => s.toDomain()).toList());
        },
        onError: (e, st) => DatabaseFailure('Failed to load session $id.', cause: e),
      );

  @override
  Future<Result<String>> saveSession(Session session) => guard(
        () => _datasource.insertSession(SessionModel.fromDomain(session)),
        onError: (e, st) => DatabaseFailure('Failed to save session.', cause: e),
      );

  @override
  Future<Result<void>> updateSession(Session session) => guard(
        () => _datasource.updateSession(SessionModel.fromDomain(session)),
        onError: (e, st) => DatabaseFailure('Failed to update session.', cause: e),
      );

  @override
  Future<Result<void>> deleteSession(String id) => guard(
        () => _datasource.deleteSession(id),
        onError: (e, st) => DatabaseFailure('Failed to delete session $id.', cause: e),
      );

  // ── Shots ──────────────────────────────────────────────────────────────────

  @override
  Future<Result<List<ShotResult>>> getShotsForSession(String sessionId) => guard(
        () async {
          final models = await _datasource.getShotsForSession(sessionId);
          return models.map((m) => m.toDomain()).toList();
        },
        onError: (e, st) => DatabaseFailure('Failed to load shots.', cause: e),
      );

  @override
  Future<Result<String>> saveShot(ShotResult shot) => guard(
        () => _datasource.insertShot(ShotModel.fromDomain(shot)),
        onError: (e, st) => DatabaseFailure('Failed to save shot.', cause: e),
      );

  @override
  Future<Result<void>> updateShot(ShotResult shot) => guard(
        () => _datasource.updateShot(ShotModel.fromDomain(shot)),
        onError: (e, st) => DatabaseFailure('Failed to update shot.', cause: e),
      );

  @override
  Future<Result<void>> deleteShot(String id) => guard(
        () => _datasource.deleteShot(id),
        onError: (e, st) => DatabaseFailure('Failed to delete shot.', cause: e),
      );
}
