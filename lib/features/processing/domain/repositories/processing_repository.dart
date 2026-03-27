import '../../../../core/utils/result.dart';
import '../entities/processed_image.dart';

abstract interface class ProcessingRepository {
  /// Detects target rings and shot hole, returns annotated [ProcessedImage].
  Future<Result<ProcessedImage>> processImage(String imagePath);
}
