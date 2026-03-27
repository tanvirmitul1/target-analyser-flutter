import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/logger.dart';
import '../models/shot_record_model.dart';
import '../models/soldier_model.dart';
import '../../domain/repositories/soldier_repository.dart';

/// Raw SQLite access layer.
///
/// Operates exclusively with DTO types ([SoldierModel], [ShotRecordModel]).
/// No domain entities or business logic appear here.
///
/// All batch and transaction operations use sqflite's [Batch] API so that
/// multiple writes are sent as a single atomic commit.
class SoldierLocalDatasource {
  const SoldierLocalDatasource();

  Database get _db => DatabaseService.instance.db;

  // ── Soldiers ───────────────────────────────────────────────────────────────

  Future<void> upsertSoldier(SoldierModel model) async {
    await _db.insert(
      DbConstants.tableSoldier,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.d('Soldier upserted: ${model.id}');
  }

  Future<SoldierModel?> getSoldierById(String id) async {
    final rows = await _db.query(
      DbConstants.tableSoldier,
      where: '${DbConstants.colSoldierId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : SoldierModel.fromMap(rows.first);
  }

  Future<List<SoldierModel>> getAllSoldiers() async {
    final rows = await _db.query(
      DbConstants.tableSoldier,
      orderBy: DbConstants.colSoldierId,
    );
    AppLogger.d('Fetched ${rows.length} soldiers.');
    return rows.map(SoldierModel.fromMap).toList(growable: false);
  }

  Future<void> deleteSoldier(String id) async {
    final deleted = await _db.delete(
      DbConstants.tableSoldier,
      where: '${DbConstants.colSoldierId} = ?',
      whereArgs: [id],
    );
    AppLogger.d('Soldier deleted: $id ($deleted rows)');
  }

  // ── Shot records — single insert ───────────────────────────────────────────

  Future<int> insertShotRecord(ShotRecordModel model) async {
    final id = await _db.insert(
      DbConstants.tableSoldierShot,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    AppLogger.d('ShotRecord inserted: id=$id soldier=${model.soldierId}');
    return id;
  }

  // ── Shot records — batch insert ────────────────────────────────────────────

  /// Inserts all [models] in a single sqflite [Batch] (one transaction).
  ///
  /// Returns the auto-assigned ids in insertion order.
  ///
  /// Performance note: SQLite can process thousands of rows/s inside a single
  /// transaction.  Calling [insertShotRecord] in a loop opens a transaction
  /// per call and is ~100× slower for large sets.
  Future<List<int>> batchInsertShotRecords(
    List<ShotRecordModel> models,
  ) async {
    if (models.isEmpty) return const [];

    final batch = _db.batch();
    for (final m in models) {
      batch.insert(
        DbConstants.tableSoldierShot,
        m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    }

    // commit() returns a List<Object?> where each element is the rowid (int)
    // for an INSERT.
    final results = await batch.commit(noResult: false);
    final ids     = results.whereType<int>().toList(growable: false);

    AppLogger.d(
      'batchInsert: ${models.length} shot records → ids ${ids.first}…${ids.last}',
    );
    return ids;
  }

  // ── Shot records — query ───────────────────────────────────────────────────

  /// Builds and executes a filtered, paginated SELECT against [tableSoldierShot].
  Future<List<ShotRecordModel>> queryShotHistory(
    ShotHistoryQuery query,
  ) async {
    // ── Build WHERE clause ───────────────────────────────────────────────────
    final conditions = <String>[
      '${DbConstants.colSoldierShotSoldierId} = ?',
    ];
    final args = <Object?>[query.soldierId];

    if (query.from != null) {
      conditions.add('${DbConstants.colSoldierShotCreatedAt} >= ?');
      args.add(query.from!.toUtc().millisecondsSinceEpoch);
    }
    if (query.to != null) {
      conditions.add('${DbConstants.colSoldierShotCreatedAt} <= ?');
      args.add(query.to!.toUtc().millisecondsSinceEpoch);
    }
    if (query.pattern != null) {
      conditions.add('${DbConstants.colSoldierShotPattern} = ?');
      args.add(query.pattern);
    }
    if (query.errorType != null) {
      conditions.add('${DbConstants.colSoldierShotErrorType} = ?');
      args.add(query.errorType);
    }

    final rows = await _db.query(
      DbConstants.tableSoldierShot,
      where:   conditions.join(' AND '),
      whereArgs: args,
      orderBy: '${DbConstants.colSoldierShotCreatedAt} DESC',
      limit:   query.limit,
      offset:  query.offset,
    );

    AppLogger.d(
      'queryShotHistory(${query.soldierId}): '
      '${rows.length} rows (limit=${query.limit}, offset=${query.offset})',
    );
    return rows.map(ShotRecordModel.fromMap).toList(growable: false);
  }

  Future<int> countShots(String soldierId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${DbConstants.tableSoldierShot} '
      'WHERE ${DbConstants.colSoldierShotSoldierId} = ?',
      [soldierId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> clearHistory(String soldierId) async {
    final deleted = await _db.delete(
      DbConstants.tableSoldierShot,
      where: '${DbConstants.colSoldierShotSoldierId} = ?',
      whereArgs: [soldierId],
    );
    AppLogger.d('clearHistory($soldierId): $deleted rows removed.');
  }
}
