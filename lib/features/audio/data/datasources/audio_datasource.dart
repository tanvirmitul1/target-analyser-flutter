import 'package:audioplayers/audioplayers.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

/// Low-latency audio playback backed by the `audioplayers` package.
///
/// ## Error-sound preloading
/// One [AudioPlayer] is created per error sound and kept alive for the lifetime
/// of the datasource.  [preload] calls [AudioPlayer.setSourceAsset] on each
/// player during app startup so the native audio buffer is already warmed by
/// the time [playErrorSound] is first called.
///
/// ## No-overlap guarantee
/// [playErrorSound] tracks the last active player and calls [AudioPlayer.stop]
/// on it (fire-and-forget) before resuming the new one.  Because all players
/// share a single asset source (set at preload time), a stopped player can be
/// replayed cheaply with [AudioPlayer.seek] + [AudioPlayer.resume] instead of
/// re-reading from disk.
class AudioDatasource {
  AudioDatasource();

  // ── Score-feedback player ──────────────────────────────────────────────────

  final AudioPlayer _scorePlayer = AudioPlayer();

  // ── Error-sound player pool ────────────────────────────────────────────────

  /// Asset paths keyed by the canonical error identifier string.
  ///
  /// Strings are deliberately decoupled from the domain enum so this class
  /// has no dependency on the analysis feature.
  static const Map<String, String> _errorAssets = {
    'jerk':   'audio/trigger_control.mp3',
    'buck':   'audio/grip_stable.mp3',
    'flinch': 'audio/relax.mp3',
  };

  /// One preloaded player per entry in [_errorAssets].
  final Map<String, AudioPlayer> _errorPlayers = {};

  /// The player that is currently playing (or last played) an error sound.
  AudioPlayer? _activeErrorPlayer;

  bool _preloaded = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Warms the native audio buffer for each error sound.
  ///
  /// Should be called once during app startup and awaited before the first
  /// [playErrorSound] call.  Calling more than once is a no-op.
  Future<void> preload() async {
    if (_preloaded) return;
    await _scorePlayer.setVolume(AppConstants.defaultVolume);

    for (final entry in _errorAssets.entries) {
      final player = AudioPlayer();
      await player.setVolume(AppConstants.defaultVolume);
      // setSourceAsset loads the asset into the native player; subsequent
      // resume() calls skip disk I/O entirely.
      await player.setSourceAsset(entry.value);
      _errorPlayers[entry.key] = player;
    }

    _preloaded = true;
    AppLogger.d(
      'AudioDatasource: ${_errorPlayers.length} error sounds preloaded.',
    );
  }

  Future<void> dispose() async {
    await _scorePlayer.dispose();
    for (final p in _errorPlayers.values) {
      await p.dispose();
    }
  }

  // ── Score-feedback playback ────────────────────────────────────────────────

  /// Plays an arbitrary asset by path (used for score-feedback sounds).
  ///
  /// Does NOT stop error-sound players — score feedback and error sounds use
  /// separate players so they never interfere.
  Future<void> play(String assetPath) async {
    AppLogger.d('AudioDatasource: playing $assetPath');
    await _scorePlayer.play(AssetSource(assetPath));
  }

  // ── Error-sound playback ───────────────────────────────────────────────────

  /// Stops any currently playing error sound and plays the one mapped to
  /// [errorKey] from the beginning.
  ///
  /// [errorKey] must be one of the keys in [_errorAssets] ('jerk', 'buck',
  /// 'flinch').  Unknown keys are logged and silently ignored.
  ///
  /// Because each player's source is already preloaded, latency between this
  /// call and audible output is typically < 20 ms on Android.
  Future<void> playErrorSound(String errorKey) async {
    final player = _errorPlayers[errorKey];
    if (player == null) {
      AppLogger.w('AudioDatasource: unknown error key "$errorKey" — skipped.');
      return;
    }

    // Stop the current player without awaiting to avoid blocking the new play.
    _activeErrorPlayer?.stop();
    _activeErrorPlayer = player;

    // Rewind then resume; source is already loaded so this is very fast.
    await player.seek(Duration.zero);
    await player.resume();

    AppLogger.d('AudioDatasource: playing error sound "$errorKey"');
  }

  // ── Volume ─────────────────────────────────────────────────────────────────

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    await _scorePlayer.setVolume(v);
    for (final p in _errorPlayers.values) {
      await p.setVolume(v);
    }
  }
}
