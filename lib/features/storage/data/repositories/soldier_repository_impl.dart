import '../../../../core/utils/result.dart';
import '../../domain/entities/shot_record.dart';
import '../../domain/entities/soldier.dart';
import '../../domain/repositories/soldier_repository.dart';
import '../datasources/soldier_local_datasource.dart';
import '../models/shot_record_model.dart';
import '../models/soldier_model.dart';

/// Concrete implementation of [SoldierRepository] backed by SQLite.
///
/// Every public method delegates to [SoldierLocalDatasource] and wraps the
/// call in [guard] so that raw [DatabaseException]s never escape this layer.
class SoldierRepositoryImpl implements SoldierRepository {
  const SoldierRepositoryImpl(this._datasource);

  final SoldierLocalDatasource _datasource;

  // ── Soldiers ───────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> upsertSoldier(Soldier soldier) => guard(
        () => _datasource.upsertSoldier(SoldierModel.fromDomain(soldier)),
        onError: (e, st) => DatabaseFailure('upsertSoldier failed', cause: e),
      );

  @override
  Future<Result<Soldier?>> getSoldierById(String id) => guard(
        () async {
          final model = await _datasource.getSoldierById(id);
          return model?.toDomain();
        },
        onError: (e, st) => DatabaseFailure('getSoldierById failed', cause: e),
      );

  @override
  Future<Result<List<Soldier>>> getAllSoldiers() => guard(
        () async {
          final models = await _datasource.getAllSoldiers();
          return models.map((m) => m.toDomain()).toList(growable: false);
        },
        onError: (e, st) => DatabaseFailure('getAllSoldiers failed', cause: e),
      );

  @override
  Future<Result<void>> deleteSoldier(String id) => guard(
        () => _datasource.deleteSoldier(id),
        onError: (e, st) => DatabaseFailure('deleteSoldier failed', cause: e),
      );

  // ── Shot records ───────────────────────────────────────────────────────────

  @override
  Future<Result<int>> insertShotRecord(ShotRecord record) => guard(
        () => _datasource.insertShotRecord(ShotRecordModel.fromDomain(record)),
        onError: (e, st) =>
            DatabaseFailure('insertShotRecord failed', cause: e),
      );

  @override
  Future<Result<List<int>>> batchInsertShotRecords(
    List<ShotRecord> records,
  ) =>
      guard(
        () => _datasource.batchInsertShotRecords(
          records.map(ShotRecordModel.fromDomain).toList(growable: false),
        ),
        onError: (e, st) =>
            DatabaseFailure('batchInsertShotRecords failed', cause: e),
      );

  @override
  Future<Result<List<ShotRecord>>> getShotHistory(
    ShotHistoryQuery query,
  ) =>
      guard(
        () async {
          final models = await _datasource.queryShotHistory(query);
          return models.map((m) => m.toDomain()).toList(growable: false);
        },
        onError: (e, st) => DatabaseFailure('getShotHistory failed', cause: e),
      );

  @override
  Future<Result<int>> countShots(String soldierId) => guard(
        () => _datasource.countShots(soldierId),
        onError: (e, st) => DatabaseFailure('countShots failed', cause: e),
      );

  @override
  Future<Result<void>> clearHistory(String soldierId) => guard(
        () => _datasource.clearHistory(soldierId),
        onError: (e, st) => DatabaseFailure('clearHistory failed', cause: e),
      );
}
