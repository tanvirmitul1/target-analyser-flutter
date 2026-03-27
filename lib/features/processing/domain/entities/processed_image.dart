import 'package:equatable/equatable.dart';

/// Pixel coordinate of a detected shot hole.
///
/// Coordinates are in the processed (resized) image's pixel space.
class ShotPoint extends Equatable {
  const ShotPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => 'ShotPoint(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

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
    required this.imageWidthPx,
    required this.imageHeightPx,
    required this.allShots,
    this.usedFallback = false,
  });

  /// Path to the source image (may be the compressed version).
  final String originalPath;

  /// Path to the annotated output image saved by the native layer.
  final String processedPath;

  /// Detected target centre in image coordinates (pixels).
  final double centreX;
  final double centreY;

  /// Detected outer radius of the target in pixels.
  final double targetRadiusPx;

  /// Primary detected shot hole centre (first / best shot) in image pixels.
  final double shotX;
  final double shotY;

  final DateTime processedAt;

  /// Pixel dimensions of the processed (annotated) image.
  /// Used by [ShotOverlayPainter] to compute display-space scale.
  final int imageWidthPx;
  final int imageHeightPx;

  /// All detected shot centres in image-pixel coordinates.
  /// Contains at least one entry (the primary shot) when a shot was detected.
  final List<ShotPoint> allShots;

  /// True when native OpenCV processing failed and the pure-Dart fallback was used.
  final bool usedFallback;

  // ── Computed helpers ───────────────────────────────────────────────────────

  /// Offset of the primary shot from the target centre, normalised by radius.
  /// Range: −1.0 … 1.0.  Returns 0 when radius is zero.
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
        imageWidthPx,
        imageHeightPx,
        allShots,
        usedFallback,
      ];
}
