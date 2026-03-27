import '../../../../core/utils/result.dart';
import '../entities/shot_pattern.dart';
import '../repositories/shot_pattern_repository.dart';

/// Orchestrates a shot-pattern analysis for a given set of shots.
///
/// The use case keeps the call-site decoupled from the repository choice and
/// provides a single, testable entry point for the analysis flow.
class AnalyseShotPatternUseCase {
  const AnalyseShotPatternUseCase(this._repository);
  final ShotPatternRepository _repository;

  Future<Result<ShotPattern>> call({
    required ShotPoint center,
    required List<ShotPoint> shots,
  }) =>
      _repository.analyse(center: center, shots: shots);
}
