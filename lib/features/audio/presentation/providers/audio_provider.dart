import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/audio_datasource.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/usecases/play_feedback_usecase.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final audioDatasourceProvider = Provider<AudioDatasource>(
  (ref) {
    final ds = AudioDatasource();
    ref.onDispose(ds.dispose);
    return ds;
  },
);

final audioRepositoryProvider = Provider<AudioRepository>(
  (ref) => AudioRepositoryImpl(ref.watch(audioDatasourceProvider)),
);

final playFeedbackUseCaseProvider = Provider<PlayFeedbackUseCase>(
  (ref) => PlayFeedbackUseCase(ref.watch(audioRepositoryProvider)),
);

// ── Audio state notifier ──────────────────────────────────────────────────────

class AudioState {
  const AudioState({this.volume = 0.8, this.isMuted = false});
  final double volume;
  final bool isMuted;
}

class AudioNotifier extends Notifier<AudioState> {
  @override
  AudioState build() => const AudioState();

  Future<void> playShotFeedback(double score) async {
    if (state.isMuted) return;
    await ref.read(playFeedbackUseCaseProvider)(score);
  }

  Future<void> setVolume(double volume) async {
    final result = await ref.read(audioRepositoryProvider).setVolume(volume);
    if (result.isSuccess) state = AudioState(volume: volume, isMuted: state.isMuted);
  }

  void toggleMute() {
    state = AudioState(volume: state.volume, isMuted: !state.isMuted);
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(
  AudioNotifier.new,
);
