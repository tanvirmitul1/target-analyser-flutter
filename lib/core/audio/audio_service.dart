import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

// ── Error-type enum ───────────────────────────────────────────────────────────

/// Shot-technique errors that have an associated coaching audio cue.
enum ShotError { jerk, buck, flinch }

// ── Audio-asset mapping ───────────────────────────────────────────────────────

const _errorAssets = {
  ShotError.jerk:   'audio/trigger_control.mp3',
  ShotError.buck:   'audio/grip_stable.mp3',
  ShotError.flinch: 'audio/relax.mp3',
};

// ── AudioService ──────────────────────────────────────────────────────────────

/// Manages a small pool of [AudioPlayer]s so that:
///   - All audio assets are preloaded into OS audio buffers on first use.
///   - Playback calls are non-blocking and do not overlap with each other.
///   - The service can be released cleanly (e.g. on app background / dispose).
///
/// Use via [audioServiceProvider].
class AudioService {
  AudioService() {
    _init();
  }

  // One dedicated player per asset keeps latency minimal and avoids allocation
  // at playback time.
  final Map<String, AudioPlayer> _players = {};
  bool _ready = false;

  /// Returns true once all players have been created and the sources cached.
  bool get isReady => _ready;

  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    final allAssets = {
      ..._errorAssets.values,
      'audio/bullseye.mp3',
      'audio/good_shot.mp3',
      'audio/miss.mp3',
    };

    for (final asset in allAssets) {
      final player = AudioPlayer();
      // Release-mode: stop any existing playback before reusing the player.
      await player.setReleaseMode(ReleaseMode.stop);
      // Cache the source into the native audio engine buffer.
      await player.setSource(AssetSource(asset));
      _players[asset] = player;
      AppLogger.d('AudioService: cached "$asset"');
    }

    _ready = true;
    AppLogger.i('AudioService: all assets preloaded (${_players.length} tracks)');
  }

  // ---------------------------------------------------------------------------

  /// Plays the coaching cue for [error].  No-ops if the service is not yet
  /// ready (preload still in progress) or if a sound is already playing.
  Future<void> playErrorSound(ShotError error) async {
    final asset = _errorAssets[error]!;
    await _play(asset);
  }

  /// Plays a positive-result sound.
  /// [asset] must be one of the bundled audio keys (e.g. `'audio/bullseye.mp3'`).
  Future<void> playResultSound(String asset) async {
    await _play(asset);
  }

  Future<void> _play(String asset) async {
    if (!_ready) {
      AppLogger.w('AudioService: not ready — skipping "$asset"');
      return;
    }
    final player = _players[asset];
    if (player == null) {
      AppLogger.w('AudioService: unknown asset "$asset"');
      return;
    }
    // If already playing, let the current playback finish (no overlap).
    if (player.state == PlayerState.playing) return;

    try {
      await player.resume();
    } catch (e) {
      AppLogger.e('AudioService: playback error for "$asset"', error: e);
    }
  }

  // ---------------------------------------------------------------------------

  /// Releases all native audio resources.  Call from a [WidgetRef] dispose or
  /// app-lifecycle handler.
  Future<void> dispose() async {
    for (final entry in _players.entries) {
      await entry.value.dispose();
      AppLogger.d('AudioService: released "${entry.key}"');
    }
    _players.clear();
    _ready = false;
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

/// Application-scoped [AudioService].
///
/// Automatically disposes the service (releases native audio resources) when
/// the provider is removed from the container.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
