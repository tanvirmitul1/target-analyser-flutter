import '../../../../core/utils/result.dart';
import '../../domain/entities/shot_pattern.dart';
import '../../domain/repositories/shot_pattern_repository.dart';
import '../services/shot_analysis_service.dart';

/// Runs [ShotAnalysisService.analyse] on an isolate-friendly background
/// compute path, wrapped in [guard] so callers always receive a [Result].
class ShotPatternRepositoryImpl implements ShotPatternRepository {
  const ShotPatternRepositoryImpl(this._service);
  final ShotAnalysisService _service;

  @override
  Future<Result<ShotPattern>> analyse({
    required ShotPoint center,
    required List<ShotPoint> shots,
  }) =>
      guard(
        // [ShotAnalysisService.analyse] is synchronous CPU work.  Wrapping it
        // in an async guard keeps the call-site uniform and allows the compute
        // to be moved to an Isolate later without touching the domain layer.
        () async => _service.analyse(center: center, shots: shots),
        onError: (e, st) =>
            AnalysisFailure('Shot pattern analysis failed.', cause: e),
      );
}
