import '../../../../core/utils/result.dart';
import '../../../analysis/domain/entities/shot_pattern.dart';
import '../../domain/repositories/audio_repository.dart';
import '../datasources/audio_datasource.dart';

class AudioRepositoryImpl implements AudioRepository {
  const AudioRepositoryImpl(this._datasource);

  final AudioDatasource _datasource;

  // ── Score-feedback assets ──────────────────────────────────────────────────

  static const _bullseye = 'audio/bullseye.mp3';
  static const _good     = 'audio/good_shot.mp3';
  static const _miss     = 'audio/miss.mp3';
  static const _success  = 'audio/success.mp3';
  static const _error    = 'audio/error.mp3';

  // ── Error-sound mapping ────────────────────────────────────────────────────

  /// Maps [ShooterError] values to the string keys used by [AudioDatasource].
  ///
  /// Keys match [AudioDatasource._errorAssets]; decoupled so the datasource
  /// has no dependency on the analysis domain.
  static const Map<ShooterError, String> _errorKeys = {
    ShooterError.jerk:   'jerk',
    ShooterError.buck:   'buck',
    ShooterError.flinch: 'flinch',
  };

  // ── AudioRepository ────────────────────────────────────────────────────────

  @override
  Future<Result<void>> playShotFeedback(double score) => guard(
        () async {
          if (score >= 10) {
            await _datasource.play(_bullseye);
          } else if (score >= 7) {
            await _datasource.play(_good);
          } else {
            await _datasource.play(_miss);
          }
        },
        onError: (e, st) =>
            AudioFailure('Could not play feedback.', cause: e),
      );

  @override
  Future<Result<void>> playSuccess() => guard(
        () => _datasource.play(_success),
        onError: (e, st) =>
            AudioFailure('Could not play success sound.', cause: e),
      );

  @override
  Future<Result<void>> playError() => guard(
        () => _datasource.play(_error),
        onError: (e, st) =>
            AudioFailure('Could not play error sound.', cause: e),
      );

  @override
  Future<Result<void>> playErrorSound(ShooterError error) => guard(
        () => _datasource.playErrorSound(_errorKeys[error]!),
        onError: (e, st) =>
            AudioFailure('Could not play error sound for $error.', cause: e),
      );

  @override
  Future<Result<void>> setVolume(double volume) => guard(
        () => _datasource.setVolume(volume),
        onError: (e, st) =>
            AudioFailure('Could not set volume.', cause: e),
      );
}
