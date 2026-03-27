import '../../domain/entities/processed_image.dart';

class ProcessedImageModel {
  const ProcessedImageModel({
    required this.originalPath,
    required this.processedPath,
    required this.centreX,
    required this.centreY,
    required this.targetRadiusPx,
    required this.shotX,
    required this.shotY,
    required this.processedAt,
    required this.imageWidthPx,
    required this.imageHeightPx,
    required this.allShots,
    this.usedFallback = false,
  });

  final String originalPath;
  final String processedPath;
  final double centreX;
  final double centreY;
  final double targetRadiusPx;
  final double shotX;
  final double shotY;
  final String processedAt;
  final int    imageWidthPx;
  final int    imageHeightPx;

  /// All detected shot centres in image-pixel space.
  final List<ShotPoint> allShots;

  /// Mirrors [ProcessedImage.usedFallback].
  final bool usedFallback;

  ProcessedImage toDomain() => ProcessedImage(
        originalPath:   originalPath,
        processedPath:  processedPath,
        centreX:        centreX,
        centreY:        centreY,
        targetRadiusPx: targetRadiusPx,
        shotX:          shotX,
        shotY:          shotY,
        processedAt:    DateTime.parse(processedAt),
        imageWidthPx:   imageWidthPx,
        imageHeightPx:  imageHeightPx,
        allShots:       allShots,
        usedFallback:   usedFallback,
      );
}
