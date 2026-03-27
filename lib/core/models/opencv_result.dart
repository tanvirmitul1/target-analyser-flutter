import 'package:equatable/equatable.dart';

/// Typed representation of the JSON emitted by [ImageProcessor.kt].
///
/// Schema:
/// ```json
/// {
///   "center":               {"x": float, "y": float},
///   "target_radius":        float,
///   "processed_image_path": string,
///   "shots":                [{"x": float, "y": float}],
///   "debug": {
///     "circles_detected":   int,
///     "shots_found":        int,
///     "image_width":        int,
///     "image_height":       int,
///     "processing_time_ms": int
///   }
/// }
/// ```
class OpenCvResult extends Equatable {
  const OpenCvResult({
    required this.center,
    required this.targetRadius,
    required this.processedImagePath,
    required this.shots,
    required this.debug,
  });

  final Point2d center;

  /// Detected target outer radius in pixels.
  final double targetRadius;

  /// Absolute path to the annotated JPEG saved by [ImageProcessor].
  /// Empty string if saving failed (non-fatal — processing data still valid).
  final String processedImagePath;

  final List<Point2d> shots;
  final OpenCvDebugInfo debug;

  bool get hasProcessedImage => processedImagePath.isNotEmpty;
  bool get hasShots => shots.isNotEmpty;

  /// Offset of the primary (first) shot from the target centre, normalised
  /// by [targetRadius].  Returns (0,0) when no shots were detected.
  (double, double) get normalisedPrimaryOffset {
    if (shots.isEmpty || targetRadius == 0) return (0.0, 0.0);
    final s = shots.first;
    return (
      (s.x - center.x) / targetRadius,
      (s.y - center.y) / targetRadius,
    );
  }

  factory OpenCvResult.fromJson(Map<String, dynamic> json) {
    return OpenCvResult(
      center: Point2d.fromJson(
        json['center'] as Map<String, dynamic>,
      ),
      targetRadius: (json['target_radius'] as num?)?.toDouble() ?? 0,
      processedImagePath: json['processed_image_path'] as String? ?? '',
      shots: (json['shots'] as List<dynamic>? ?? [])
          .map((s) => Point2d.fromJson(s as Map<String, dynamic>))
          .toList(),
      debug: OpenCvDebugInfo.fromJson(
        json['debug'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  @override
  List<Object?> get props =>
      [center, targetRadius, processedImagePath, shots, debug];
}

// ── Point2d ───────────────────────────────────────────────────────────────────

class Point2d extends Equatable {
  const Point2d(this.x, this.y);

  final double x;
  final double y;

  factory Point2d.fromJson(Map<String, dynamic> json) => Point2d(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  Map<String, double> toJson() => {'x': x, 'y': y};

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => 'Point2d(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

// ── Debug info ────────────────────────────────────────────────────────────────

class OpenCvDebugInfo extends Equatable {
  const OpenCvDebugInfo({
    required this.circlesDetected,
    required this.shotsFound,
    required this.imageWidth,
    required this.imageHeight,
    required this.processingTimeMs,
  });

  final int circlesDetected;
  final int shotsFound;
  final int imageWidth;
  final int imageHeight;

  /// Wall-clock time for the native processing (not round-trip).
  final int processingTimeMs;

  factory OpenCvDebugInfo.fromJson(Map<String, dynamic> json) => OpenCvDebugInfo(
        circlesDetected: json['circles_detected'] as int? ?? 0,
        shotsFound:      json['shots_found']      as int? ?? 0,
        imageWidth:      json['image_width']      as int? ?? 0,
        imageHeight:     json['image_height']     as int? ?? 0,
        processingTimeMs: json['processing_time_ms'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [
        circlesDetected,
        shotsFound,
        imageWidth,
        imageHeight,
        processingTimeMs,
      ];

  @override
  String toString() =>
      'OpenCvDebugInfo(circles=$circlesDetected shots=$shotsFound '
      '${imageWidth}x${imageHeight} ${processingTimeMs}ms)';
}
