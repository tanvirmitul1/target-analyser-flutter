import '../../../../core/utils/result.dart';
import '../entities/shot_pattern.dart';

abstract interface class ShotPatternRepository {
  /// Analyses the given [shots] relative to [center] and returns a
  /// [ShotPattern].  This is a CPU-bound operation, not I/O — the [Result]
  /// wrapper ensures errors are typed and propagated without throwing.
  Future<Result<ShotPattern>> analyse({
    required ShotPoint center,
    required List<ShotPoint> shots,
  });
}
