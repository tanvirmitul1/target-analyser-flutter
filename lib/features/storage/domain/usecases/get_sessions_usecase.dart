import '../../../../core/utils/result.dart';
import '../entities/session.dart';
import '../repositories/storage_repository.dart';

class GetSessionsUseCase {
  const GetSessionsUseCase(this._repository);
  final StorageRepository _repository;

  Future<Result<List<Session>>> call() => _repository.getSessions();
}
