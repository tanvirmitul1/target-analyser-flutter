import 'package:equatable/equatable.dart';

class ProcessedImage extends Equatable {
  const ProcessedImage({
    required this.originalPath,
    required this.processedPath,
    required this.centreX,
    required this.centreY,
    required this.targetRadiusPx,
    required this.shotX,
    required this.shotY,
    required this.processedAt,
    this.usedFallback = false,
  });

  /// Path to the source image (may be the compressed version).
  final String originalPath;

  /// Path to the annotated output image.
  final String processedPath;

  /// Detected target centre in image coordinates (pixels).
  final double centreX;
  final double centreY;

  /// Detected outer radius of the target in pixels.
  final double targetRadiusPx;

  /// Detected shot hole centre in image coordinates.
  final double shotX;
  final double shotY;

  final DateTime processedAt;

  /// True when native OpenCV processing failed and the pure-Dart fallback
  /// detector was used instead.  Exposed to the UI so the user can be informed.
  final bool usedFallback;

  /// Offset of shot from target centre, normalised by radius (−1.0 … 1.0).
  double get normalisedOffsetX =>
      targetRadiusPx == 0 ? 0 : (shotX - centreX) / targetRadiusPx;
  double get normalisedOffsetY =>
      targetRadiusPx == 0 ? 0 : (shotY - centreY) / targetRadiusPx;

  @override
  List<Object?> get props => [
        originalPath,
        processedPath,
        centreX,
        centreY,
        targetRadiusPx,
        shotX,
        shotY,
        processedAt,
        usedFallback,
      ];
}
