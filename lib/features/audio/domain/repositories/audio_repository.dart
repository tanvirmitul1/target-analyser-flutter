import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_pattern.dart';

abstract interface class AudioRepository {
  Future<Result<void>> playShotFeedback(double score);
  Future<Result<void>> playSuccess();
  Future<Result<void>> playError();

  /// Plays the coaching sound associated with [error].
  ///
  /// Mapping:
  /// - [ShooterError.jerk]   → trigger_control.mp3
  /// - [ShooterError.buck]   → grip_stable.mp3
  /// - [ShooterError.flinch] → relax.mp3
  ///
  /// Stops any previously playing error sound before starting the new one.
  Future<Result<void>> playErrorSound(ShooterError error);

  Future<Result<void>> setVolume(double volume);
}
