import '../../../../core/utils/result.dart';
import '../repositories/audio_repository.dart';

class PlayFeedbackUseCase {
  const PlayFeedbackUseCase(this._repository);
  final AudioRepository _repository;

  Future<Result<void>> call(double score) =>
      _repository.playShotFeedback(score);
}
