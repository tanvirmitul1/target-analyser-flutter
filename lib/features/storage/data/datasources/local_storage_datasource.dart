import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/logger.dart';
import '../models/session_model.dart';
import '../models/shot_model.dart';

/// Raw SQLite access — only works with DTOs, never with domain entities.
class LocalStorageDatasource {
  const LocalStorageDatasource();

  Database get _db => DatabaseService.instance.db;

  // ── Sessions ───────────────────────────────────────────────────────────────

  Future<List<SessionModel>> getSessions() async {
    final rows = await _db.query(
      DbConstants.tableSession,
      orderBy: '${DbConstants.colSessionCreatedAt} DESC',
    );
    AppLogger.d('Fetched ${rows.length} sessions from DB.');
    return rows.map(SessionModel.fromMap).toList();
  }

  Future<SessionModel?> getSessionById(String id) async {
    final rows = await _db.query(
      DbConstants.tableSession,
      where: '${DbConstants.colSessionId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : SessionModel.fromMap(rows.first);
  }

  Future<String> insertSession(SessionModel model) async {
    await _db.insert(
      DbConstants.tableSession,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.d('Session inserted: ${model.id}');
    return model.id;
  }

  Future<void> updateSession(SessionModel model) async {
    await _db.update(
      DbConstants.tableSession,
      model.toMap(),
      where: '${DbConstants.colSessionId} = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> deleteSession(String id) async {
    await _db.delete(
      DbConstants.tableSession,
      where: '${DbConstants.colSessionId} = ?',
      whereArgs: [id],
    );
    AppLogger.d('Session deleted: $id');
  }

  // ── Shots ──────────────────────────────────────────────────────────────────

  Future<List<ShotModel>> getShotsForSession(String sessionId) async {
    final rows = await _db.query(
      DbConstants.tableShot,
      where: '${DbConstants.colShotSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: '${DbConstants.colShotTimestamp} ASC',
    );
    return rows.map(ShotModel.fromMap).toList();
  }

  Future<String> insertShot(ShotModel model) async {
    await _db.insert(
      DbConstants.tableShot,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.d('Shot inserted: ${model.id}');
    return model.id;
  }

  Future<void> updateShot(ShotModel model) async {
    await _db.update(
      DbConstants.tableShot,
      model.toMap(),
      where: '${DbConstants.colShotId} = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> deleteShot(String id) async {
    await _db.delete(
      DbConstants.tableShot,
      where: '${DbConstants.colShotId} = ?',
      whereArgs: [id],
    );
  }
}
