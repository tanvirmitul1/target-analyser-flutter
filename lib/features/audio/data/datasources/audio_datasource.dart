import 'package:audioplayers/audioplayers.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

/// Wraps the `audioplayers` package.
class AudioDatasource {
  AudioDatasource() {
    _player.setVolume(AppConstants.defaultVolume);
  }

  final AudioPlayer _player = AudioPlayer();

  Future<void> play(String assetPath) async {
    AppLogger.d('Playing audio: $assetPath');
    await _player.play(AssetSource(assetPath));
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
