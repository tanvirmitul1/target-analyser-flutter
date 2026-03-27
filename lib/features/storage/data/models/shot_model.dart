import '../../../../core/constants/db_constants.dart';
import '../../../analysis/domain/entities/shot_result.dart';

/// Data-layer DTO for [ShotResult].
class ShotModel {
  const ShotModel({
    required this.id,
    required this.sessionId,
    required this.imagePath,
    required this.score,
    required this.ring,
    required this.x,
    required this.y,
    required this.timestamp,
    this.processedImagePath,
  });

  final String id;
  final String sessionId;
  final String imagePath;
  final String? processedImagePath;
  final double score;
  final int ring;
  final double x;
  final double y;
  final String timestamp;

  factory ShotModel.fromMap(Map<String, dynamic> map) => ShotModel(
        id: map[DbConstants.colShotId] as String,
        sessionId: map[DbConstants.colShotSessionId] as String,
        imagePath: map[DbConstants.colShotImagePath] as String,
        processedImagePath: map[DbConstants.colShotProcessedPath] as String?,
        score: (map[DbConstants.colShotScore] as num).toDouble(),
        ring: map[DbConstants.colShotRing] as int,
        x: (map[DbConstants.colShotX] as num).toDouble(),
        y: (map[DbConstants.colShotY] as num).toDouble(),
        timestamp: map[DbConstants.colShotTimestamp] as String,
      );

  Map<String, dynamic> toMap() => {
        DbConstants.colShotId: id,
        DbConstants.colShotSessionId: sessionId,
        DbConstants.colShotImagePath: imagePath,
        DbConstants.colShotProcessedPath: processedImagePath,
        DbConstants.colShotScore: score,
        DbConstants.colShotRing: ring,
        DbConstants.colShotX: x,
        DbConstants.colShotY: y,
        DbConstants.colShotTimestamp: timestamp,
      };

  ShotResult toDomain() => ShotResult(
        id: id,
        sessionId: sessionId,
        imagePath: imagePath,
        processedImagePath: processedImagePath,
        score: score,
        ring: ring,
        offsetX: x,
        offsetY: y,
        timestamp: DateTime.parse(timestamp),
      );

  factory ShotModel.fromDomain(ShotResult s) => ShotModel(
        id: s.id,
        sessionId: s.sessionId,
        imagePath: s.imagePath,
        processedImagePath: s.processedImagePath,
        score: s.score,
        ring: s.ring,
        x: s.offsetX,
        y: s.offsetY,
        timestamp: s.timestamp.toIso8601String(),
      );
}
