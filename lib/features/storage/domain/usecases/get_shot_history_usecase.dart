import '../../../../core/utils/result.dart';
import '../entities/shot_record.dart';
import '../repositories/soldier_repository.dart';

class GetShotHistoryUseCase {
  const GetShotHistoryUseCase(this._repository);
  final SoldierRepository _repository;

  Future<Result<List<ShotRecord>>> call(ShotHistoryQuery query) =>
      _repository.getShotHistory(query);
}
