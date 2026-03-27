import '../../../../core/utils/result.dart';
import '../entities/session.dart';
import '../repositories/storage_repository.dart';

class SaveSessionUseCase {
  const SaveSessionUseCase(this._repository);
  final StorageRepository _repository;

  Future<Result<String>> call(Session session) => _repository.saveSession(session);
}
