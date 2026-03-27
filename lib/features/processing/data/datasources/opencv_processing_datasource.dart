import '../../../../core/services/opencv_bridge.dart';
import '../../../../core/utils/logger.dart';
import '../models/processed_image_model.dart';
import 'base_processing_datasource.dart';
import 'image_processing_datasource.dart';

/// Image-processing datasource that delegates to the native OpenCV layer via
/// [OpenCvBridge].
///
/// If the platform channel call fails for any reason (OpenCV not initialised,
/// unsupported platform, etc.) processing falls back to the pure-Dart
/// [ImageProcessingDatasource] so the app remains functional.
class OpenCvProcessingDatasource implements BaseProcessingDatasource {
  const OpenCvProcessingDatasource({
    OpenCvBridge? bridge,
    ImageProcessingDatasource? fallback,
  })  : _bridge = bridge ?? OpenCvBridge.instance,
        _fallback = fallback ?? const ImageProcessingDatasource();

  final OpenCvBridge _bridge;
  final ImageProcessingDatasource _fallback;

  @override
  Future<ProcessedImageModel> processImage(String imagePath) async {
    AppLogger.d('OpenCvProcessingDatasource: calling bridge for "$imagePath"');

    final result = await _bridge.processImage(imagePath);

    return result.when(
      onSuccess: (opencv) {
        AppLogger.i(
          'OpenCV success — ${opencv.shots.length} shots, '
          '${opencv.debug.processingTimeMs} ms',
        );
        return _toModel(imagePath, opencv);
      },
      onFailure: (failure) {
        // Log and fall back — processing failure is non-fatal.
        AppLogger.w(
          'OpenCV bridge failed (${failure.message}) — '
          'falling back to pure-Dart processor.',
        );
        return _fallback.processImage(imagePath);
      },
    );
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  ProcessedImageModel _toModel(String imagePath, opencv) {
    // Pick the primary shot (first detected).  If none found use centre.
    final double shotX;
    final double shotY;

    if (opencv.shots.isNotEmpty) {
      shotX = opencv.shots.first.x;
      shotY = opencv.shots.first.y;
    } else {
      shotX = opencv.center.x;
      shotY = opencv.center.y;
    }

    return ProcessedImageModel(
      originalPath:    imagePath,
      processedPath:   opencv.hasProcessedImage
                           ? opencv.processedImagePath
                           : imagePath, // fallback: show raw image
      centreX:         opencv.center.x,
      centreY:         opencv.center.y,
      targetRadiusPx:  opencv.targetRadius,
      shotX:           shotX,
      shotY:           shotY,
      processedAt:     DateTime.now().toIso8601String(),
    );
  }
}
