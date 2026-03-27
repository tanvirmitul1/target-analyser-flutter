import '../../../../core/utils/result.dart';
import '../entities/shot_result.dart';
import '../../data/models/analysis_input.dart';

abstract interface class AnalysisRepository {
  /// Scores the shot given the processed image metadata.
  Future<Result<ShotResult>> analyseTarget(AnalysisInput input);
}
