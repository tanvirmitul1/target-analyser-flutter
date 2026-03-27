import 'package:equatable/equatable.dart';

/// Represents the analysis outcome for a single shot on the target.
class ShotResult extends Equatable {
  const ShotResult({
    required this.id,
    required this.sessionId,
    required this.imagePath,
    required this.score,
    required this.ring,
    required this.offsetX,
    required this.offsetY,
    required this.timestamp,
    this.processedImagePath,
  });

  /// Unique identifier for this shot.
  final String id;

  /// Parent session identifier.
  final String sessionId;

  /// Path to the raw captured image.
  final String imagePath;

  /// Path to the annotated / processed image (may be null until processed).
  final String? processedImagePath;

  /// Numeric score (e.g. 9.7 for an inner-10).
  final double score;

  /// Ring hit (1-10, or 0 if miss).
  final int ring;

  /// Horizontal offset from centre in pixels (positive = right).
  final double offsetX;

  /// Vertical offset from centre in pixels (positive = down).
  final double offsetY;

  final DateTime timestamp;

  bool get isBullseye => ring == 10;
  bool get isMiss => ring == 0;

  ShotResult copyWith({
    String? id,
    String? sessionId,
    String? imagePath,
    String? processedImagePath,
    double? score,
    int? ring,
    double? offsetX,
    double? offsetY,
    DateTime? timestamp,
  }) =>
      ShotResult(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        imagePath: imagePath ?? this.imagePath,
        processedImagePath: processedImagePath ?? this.processedImagePath,
        score: score ?? this.score,
        ring: ring ?? this.ring,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  List<Object?> get props => [
        id,
        sessionId,
        imagePath,
        processedImagePath,
        score,
        ring,
        offsetX,
        offsetY,
        timestamp,
      ];
}
