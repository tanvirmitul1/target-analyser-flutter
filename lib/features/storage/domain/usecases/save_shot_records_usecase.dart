import '../../../../core/utils/result.dart';
import '../entities/shot_record.dart';
import '../repositories/soldier_repository.dart';

/// Persists one or more [ShotRecord]s in a single atomic batch.
///
/// Always prefer [call] with a list over calling a single-insert use case
/// in a loop — the batch commits in one transaction and is significantly
/// faster for 5+ records.
class SaveShotRecordsUseCase {
  const SaveShotRecordsUseCase(this._repository);
  final SoldierRepository _repository;

  Future<Result<List<int>>> call(List<ShotRecord> records) {
    if (records.isEmpty) return Future.value(const Success([]));
    if (records.length == 1) {
      return _repository
          .insertShotRecord(records.first)
          .then((r) => r.map((id) => [id]));
    }
    return _repository.batchInsertShotRecords(records);
  }
}
