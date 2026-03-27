/// Input DTO carrying the data needed to compute a shot score.
class AnalysisInput {
  const AnalysisInput({
    required this.sessionId,
    required this.imagePath,
    required this.processedImagePath,
    required this.normalisedOffsetX,
    required this.normalisedOffsetY,
    required this.timestamp,
  });

  final String sessionId;
  final String imagePath;
  final String processedImagePath;

  /// Shot offset normalised to target radius (-1.0 … 1.0).
  final double normalisedOffsetX;
  final double normalisedOffsetY;

  final DateTime timestamp;
}
