import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_pattern.dart';
import '../repositories/audio_repository.dart';

/// Plays the coaching audio clip that corresponds to a detected [ShooterError].
///
/// Any previously playing error sound is stopped before the new one starts.
class PlayErrorSoundUseCase {
  const PlayErrorSoundUseCase(this._repository);

  final AudioRepository _repository;

  Future<Result<void>> call(ShooterError error) =>
      _repository.playErrorSound(error);
}
