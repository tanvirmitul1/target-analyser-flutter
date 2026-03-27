import '../../../../core/utils/result.dart';
import '../repositories/storage_repository.dart';

class DeleteSessionUseCase {
  const DeleteSessionUseCase(this._repository);
  final StorageRepository _repository;

  Future<Result<void>> call(String sessionId) => _repository.deleteSession(sessionId);
}
