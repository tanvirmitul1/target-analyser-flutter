import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../../../core/utils/logger.dart';
import '../models/analysis_input.dart';
import '../models/analysis_result_model.dart';

/// Converts a normalised shot offset into a score and ring number.
///
/// Scoring uses the standard 10-ring system:
///   - Ring 10 (inner-X): 0–5 % of radius → 10.9
///   - Ring 10:  0–10 % → 10.0
///   - Ring 9:  10–20 % → 9.0
///   - …
///   - Ring 1:  90–100 % → 1.0
///   - Miss:   >100 % → 0.0
class AnalysisDatasource {
  static const _uuid = Uuid();

  AnalysisResultModel analyse(AnalysisInput input) {
    final distance = math.sqrt(
      input.normalisedOffsetX * input.normalisedOffsetX +
          input.normalisedOffsetY * input.normalisedOffsetY,
    );

    final ring = _ringFromDistance(distance);
    final score = _scoreFromDistanceAndRing(distance, ring);

    AppLogger.d('Analysis: dist=$distance ring=$ring score=$score');

    return AnalysisResultModel(
      id: _uuid.v4(),
      sessionId: input.sessionId,
      imagePath: input.imagePath,
      processedImagePath: input.processedImagePath,
      score: score,
      ring: ring,
      x: input.normalisedOffsetX,
      y: input.normalisedOffsetY,
      timestamp: input.timestamp.toIso8601String(),
    );
  }

  int _ringFromDistance(double distance) {
    if (distance > 1.0) return 0; // miss
    return (10 - (distance * 10).floor()).clamp(1, 10);
  }

  double _scoreFromDistanceAndRing(double distance, int ring) {
    if (ring == 0) return 0;
    if (distance <= 0.05) return 10.9; // inner-X
    return ring.toDouble();
  }
}
