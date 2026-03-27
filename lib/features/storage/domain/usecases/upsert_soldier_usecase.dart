import '../../../../core/utils/result.dart';
import '../entities/soldier.dart';
import '../repositories/soldier_repository.dart';

class UpsertSoldierUseCase {
  const UpsertSoldierUseCase(this._repository);
  final SoldierRepository _repository;

  Future<Result<void>> call(Soldier soldier) =>
      _repository.upsertSoldier(soldier);
}
