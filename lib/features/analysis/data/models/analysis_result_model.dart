import '../../domain/entities/shot_result.dart';

class AnalysisResultModel {
  const AnalysisResultModel({
    required this.id,
    required this.sessionId,
    required this.imagePath,
    required this.processedImagePath,
    required this.score,
    required this.ring,
    required this.x,
    required this.y,
    required this.timestamp,
  });

  final String id;
  final String sessionId;
  final String imagePath;
  final String processedImagePath;
  final double score;
  final int ring;
  final double x;
  final double y;
  final String timestamp;

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
}
