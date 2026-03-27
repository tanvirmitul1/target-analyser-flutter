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
  });

  /// Path to the source image.
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

  /// Offset of shot from target centre, normalised by radius (-1.0 … 1.0).
  double get normalisedOffsetX => (shotX - centreX) / targetRadiusPx;
  double get normalisedOffsetY => (shotY - centreY) / targetRadiusPx;

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
      ];
}
