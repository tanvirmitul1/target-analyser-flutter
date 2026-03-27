import '../../../../core/utils/result.dart';
import '../entities/captured_image.dart';
import '../repositories/camera_repository.dart';

class CaptureImageUseCase {
  const CaptureImageUseCase(this._repository);
  final CameraRepository _repository;

  Future<Result<CapturedImage>> call() => _repository.captureImage();
}
