import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_result.dart';
import '../repositories/storage_repository.dart';

class SaveShotUseCase {
  const SaveShotUseCase(this._repository);
  final StorageRepository _repository;

  Future<Result<String>> call(ShotResult shot) => _repository.saveShot(shot);
}
