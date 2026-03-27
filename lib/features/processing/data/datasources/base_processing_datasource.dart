import '../models/processed_image_model.dart';

/// Contract that every image-processing datasource must satisfy.
///
/// Implementations:
///  - [ImageProcessingDatasource]  — pure Dart (fallback, no native code)
///  - [OpenCvProcessingDatasource] — Android platform channel via OpenCV
abstract interface class BaseProcessingDatasource {
  Future<ProcessedImageModel> processImage(String imagePath);
}
