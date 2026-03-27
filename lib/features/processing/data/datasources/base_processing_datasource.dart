import '../models/processed_image_model.dart';

/// Contract that every image-processing datasource must satisfy.
///
/// Implementations:
///  - [ImageProcessingDatasource]  — pure Dart (fallback, no native code)
///  - [OpenCvProcessingDatasource] — Android platform channel via OpenCV
abstract interface class BaseProcessingDatasource {
  /// Processes the image at [imagePath] and returns an annotated result model.
  ///
  /// [debugMode] is forwarded to the native layer when applicable; the
  /// pure-Dart fallback silently ignores it.
  Future<ProcessedImageModel> processImage(
    String imagePath, {
    bool debugMode = false,
  });
}
