import '../../../../core/models/opencv_result.dart';
import '../../../../core/services/opencv_bridge.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/processed_image.dart';
import '../models/processed_image_model.dart';
import 'base_processing_datasource.dart';
import 'image_processing_datasource.dart';

/// Primary image-processing datasource — delegates to native OpenCV via
/// [OpenCvBridge].
///
/// On any platform-channel failure (OpenCV not initialised, unsupported
/// platform, channel exception) processing silently falls back to the
/// pure-Dart [ImageProcessingDatasource] so the app remains functional.
///
/// [debugMode] is forwarded to the native [ImageProcessor.kt] on each call.
class OpenCvProcessingDatasource implements BaseProcessingDatasource {
  const OpenCvProcessingDatasource({
    OpenCvBridge? bridge,
    ImageProcessingDatasource? fallback,
    this.debugMode = false,
  })  : _bridge   = bridge   ?? OpenCvBridge.instance,
        _fallback  = fallback ?? const ImageProcessingDatasource();

  final OpenCvBridge _bridge;
  final ImageProcessingDatasource _fallback;

  /// Forwarded verbatim to [OpenCvBridge.processImage].
  final bool debugMode;

  @override
  Future<ProcessedImageModel> processImage(
    String imagePath, {
    bool debugMode = false,
  }) async {
    // Prefer instance-level flag (set by provider) over call-site flag.
    final effectiveDebug = this.debugMode || debugMode;
    AppLogger.d('OpenCvProcessingDatasource: bridge call for "$imagePath" '
        'debug=$effectiveDebug');

    final result = await _bridge.processImage(
      imagePath,
      debugMode: effectiveDebug,
    );

    return result.when(
      onSuccess: (opencv) {
        AppLogger.i(
          'OpenCV success — ${opencv.shots.length} shot(s)  '
          '${opencv.debug.processingTimeMs} ms',
        );
        return _toModel(imagePath, opencv);
      },
      onFailure: (failure) {
        AppLogger.w(
          'OpenCV bridge failed (${failure.message}) — '
          'falling back to pure-Dart processor.',
        );
        return _fallback.processImage(imagePath, debugMode: effectiveDebug);
      },
    );
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  ProcessedImageModel _toModel(String imagePath, OpenCvResult opencv) {
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
      originalPath:   imagePath,
      processedPath:  opencv.hasProcessedImage
                          ? opencv.processedImagePath
                          : imagePath,
      centreX:        opencv.center.x,
      centreY:        opencv.center.y,
      targetRadiusPx: opencv.targetRadius,
      shotX:          shotX,
      shotY:          shotY,
      processedAt:    DateTime.now().toIso8601String(),
      imageWidthPx:   opencv.debug.imageWidth,
      imageHeightPx:  opencv.debug.imageHeight,
      allShots:       opencv.shots
                          .map((p) => ShotPoint(p.x, p.y))
                          .toList(),
    );
  }
}
