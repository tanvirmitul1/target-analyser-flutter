import '../../../../core/utils/result.dart';
import '../../data/models/analysis_input.dart';
import '../entities/shot_result.dart';
import '../repositories/analysis_repository.dart';

class AnalyseTargetUseCase {
  const AnalyseTargetUseCase(this._repository);
  final AnalysisRepository _repository;

  Future<Result<ShotResult>> call(AnalysisInput input) =>
      _repository.analyseTarget(input);
}
