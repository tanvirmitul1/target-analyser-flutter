import '../../../../core/utils/result.dart';
import '../entities/processed_image.dart';
import '../repositories/processing_repository.dart';

class ProcessImageUseCase {
  const ProcessImageUseCase(this._repository);
  final ProcessingRepository _repository;

  Future<Result<ProcessedImage>> call(String imagePath) =>
      _repository.processImage(imagePath);
}
