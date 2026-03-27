import '../../../../core/utils/result.dart';
import '../../domain/entities/shot_result.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../datasources/analysis_datasource.dart';
import '../models/analysis_input.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {
  const AnalysisRepositoryImpl(this._datasource);
  final AnalysisDatasource _datasource;

  @override
  Future<Result<ShotResult>> analyseTarget(AnalysisInput input) => guard(
        () async => _datasource.analyse(input).toDomain(),
        onError: (e, st) =>
            AnalysisFailure('Failed to analyse shot.', cause: e),
      );
}
