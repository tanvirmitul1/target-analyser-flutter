import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/domain/entities/shot_pattern.dart';
import '../../data/datasources/audio_datasource.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/usecases/play_error_sound_usecase.dart';
import '../../domain/usecases/play_feedback_usecase.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

/// Creates and preloads the [AudioDatasource].
///
/// [AudioDatasource.preload] is fired immediately (fire-and-forget) when the
/// provider is first read — typically at app startup — so error sounds are
/// buffered in the native player well before any shot analysis completes.
final audioDatasourceProvider = Provider<AudioDatasource>(
  (ref) {
    final ds = AudioDatasource();
    // Preload is async; we intentionally do not await so the provider stays
    // synchronous.  Preloading is fast (< 200 ms on device) and will finish
    // long before the first playErrorSound call.
    ds.preload();
    ref.onDispose(ds.dispose);
    return ds;
  },
);

final audioRepositoryProvider = Provider<AudioRepository>(
  (ref) => AudioRepositoryImpl(ref.watch(audioDatasourceProvider)),
);

// ── Use-case providers ────────────────────────────────────────────────────────

final playFeedbackUseCaseProvider = Provider<PlayFeedbackUseCase>(
  (ref) => PlayFeedbackUseCase(ref.watch(audioRepositoryProvider)),
);

final playErrorSoundUseCaseProvider = Provider<PlayErrorSoundUseCase>(
  (ref) => PlayErrorSoundUseCase(ref.watch(audioRepositoryProvider)),
);

// ── Audio state ───────────────────────────────────────────────────────────────

class AudioState {
  const AudioState({this.volume = 0.8, this.isMuted = false});
  final double volume;
  final bool isMuted;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AudioNotifier extends Notifier<AudioState> {
  @override
  AudioState build() => const AudioState();

  // ── Score feedback ──────────────────────────────────────────────────────

  Future<void> playShotFeedback(double score) async {
    if (state.isMuted) return;
    await ref.read(playFeedbackUseCaseProvider)(score);
  }

  // ── Error-coaching sound ────────────────────────────────────────────────

  /// Plays the coaching sound for [error].
  ///
  /// Stops any previously playing error sound before starting the new one.
  /// Does nothing when [AudioState.isMuted] is true.
  ///
  /// ```dart
  /// ref.read(audioProvider.notifier).playErrorSound(ShooterError.jerk);
  /// ```
  Future<void> playErrorSound(ShooterError error) async {
    if (state.isMuted) return;
    await ref.read(playErrorSoundUseCaseProvider)(error);
  }

  // ── Volume / mute ───────────────────────────────────────────────────────

  Future<void> setVolume(double volume) async {
    final result =
        await ref.read(audioRepositoryProvider).setVolume(volume);
    if (result.isSuccess) {
      state = AudioState(volume: volume, isMuted: state.isMuted);
    }
  }

  void toggleMute() {
    state = AudioState(volume: state.volume, isMuted: !state.isMuted);
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(
  AudioNotifier.new,
);
