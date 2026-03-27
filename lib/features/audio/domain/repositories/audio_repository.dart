import '../../../../core/utils/result.dart';

abstract interface class AudioRepository {
  Future<Result<void>> playShotFeedback(double score);
  Future<Result<void>> playSuccess();
  Future<Result<void>> playError();
  Future<Result<void>> setVolume(double volume);
}
