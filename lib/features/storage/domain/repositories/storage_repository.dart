import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_result.dart';
import '../entities/session.dart';

/// Abstract contract — only domain types cross this boundary.
abstract interface class StorageRepository {
  // ── Sessions ───────────────────────────────────────────────────────────────
  Future<Result<List<Session>>> getSessions();
  Future<Result<Session>> getSessionById(String id);
  Future<Result<String>> saveSession(Session session);
  Future<Result<void>> updateSession(Session session);
  Future<Result<void>> deleteSession(String id);

  // ── Shots ──────────────────────────────────────────────────────────────────
  Future<Result<List<ShotResult>>> getShotsForSession(String sessionId);
  Future<Result<String>> saveShot(ShotResult shot);
  Future<Result<void>> updateShot(ShotResult shot);
  Future<Result<void>> deleteShot(String id);
}
