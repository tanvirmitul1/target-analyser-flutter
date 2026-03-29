import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/logger.dart';
import '../../../analysis/data/services/shot_analysis_service.dart';
import '../../../analysis/domain/entities/shot_pattern.dart';
import '../../../audio/presentation/providers/audio_provider.dart';
import '../../../processing/domain/entities/processed_image.dart';
import '../../../processing/presentation/providers/processing_provider.dart';
import '../../../storage/domain/entities/shot_record.dart';
import '../../../storage/domain/entities/soldier.dart';
import '../../../storage/presentation/providers/soldier_provider.dart';

// ── Argument type ─────────────────────────────────────────────────────────────

/// Riverpod family key.  Named records implement == and hashCode, so they are
/// safe as family parameters.
typedef ScanArgs = ({String imagePath, String soldierId});

// ── State hierarchy ───────────────────────────────────────────────────────────

sealed class ScanFlowState {
  const ScanFlowState();
}

/// Step 1 — image is being sent to the native OpenCV processor.
final class ScanProcessing extends ScanFlowState {
  const ScanProcessing();
}

/// Step 2 — shot-analysis service is running on the returned coordinates.
final class ScanAnalysing extends ScanFlowState {
  const ScanAnalysing(this.processed);
  final ProcessedImage processed;
}

/// Step 3 — soldier and shot record are being written to SQLite.
final class ScanSaving extends ScanFlowState {
  const ScanSaving({required this.processed, required this.pattern});
  final ProcessedImage processed;
  final ShotPattern pattern;
}

/// Terminal success state — all steps completed.
///
/// [saveWarning] is non-null when the shot record could not be persisted but
/// the analysis result is still valid and shown to the user.
final class ScanComplete extends ScanFlowState {
  const ScanComplete({
    required this.processed,
    required this.pattern,
    required this.nativeImageSize,
    this.saveWarning,
  });

  final ProcessedImage processed;
  final ShotPattern pattern;

  /// Native pixel dimensions of [processed.processedPath], decoded once so the
  /// [_ShotOverlayPainter] can compute its coordinate transform without a
  /// per-frame async decode.
  final Size nativeImageSize;

  /// Non-null when the shot record failed to persist.
  final String? saveWarning;
}

/// Terminal failure state.
final class ScanFailed extends ScanFlowState {
  const ScanFailed({required this.message, required this.step});

  final String message;

  /// Which step failed: 'processing' | 'analysing' | 'saving'.
  final String step;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Orchestrates the full scan pipeline:
///
/// 1. Process image via OpenCV platform channel.
/// 2. Run shot analysis (pattern + error type).
/// 3. Upsert soldier row + insert shot record in SQLite.
/// 4. Decode native image dimensions for the overlay painter.
/// 5. Trigger coaching audio.
///
/// Call [retry] to restart from step 1 after a failure.
class ScanFlowNotifier extends FamilyNotifier<ScanFlowState, ScanArgs> {
  bool _active = true;
  bool _running = false;

  @override
  ScanFlowState build(ScanArgs arg) {
    ref.onDispose(() => _active = false);
    _execute();
    return const ScanProcessing();
  }

  // ── Pipeline ───────────────────────────────────────────────────────────────

  Future<void> _execute() async {
    if (_running) return;
    _running = true;

    try {
      await _run();
    } finally {
      _running = false;
    }
  }

  Future<void> _run() async {
    // ── Step 1: Image processing ──────────────────────────────────────────
    if (!_active) return;
    state = const ScanProcessing();

    final processResult =
        await ref.read(processImageUseCaseProvider)(arg.imagePath);

    if (!_active) return;
    if (processResult.isFailure) {
      state = ScanFailed(
        message: processResult.failureOrNull!.message,
        step: 'processing',
      );
      return;
    }

    final processed = processResult.valueOrNull!;

    // ── Step 2: Shot analysis ─────────────────────────────────────────────
    if (!_active) return;
    state = ScanAnalysing(processed);

    final ShotPattern pattern;
    try {
      final normShots = processed.allShots.isNotEmpty
          ? processed.allShots.map((s) {
              final r = processed.targetRadiusPx;
              return (
                x: r == 0 ? 0.0 : (s.x - processed.centreX) / r,
                y: r == 0 ? 0.0 : (s.y - processed.centreY) / r,
              );
            }).toList()
          : [(x: processed.normalisedOffsetX, y: processed.normalisedOffsetY)];

      pattern = const ShotAnalysisService().analyse(
        center: (x: 0.0, y: 0.0),
        shots: normShots,
      );
    } catch (e, st) {
      AppLogger.e('Shot analysis failed', error: e, stackTrace: st);
      if (!_active) return;
      state = ScanFailed(message: e.toString(), step: 'analysing');
      return;
    }

    // ── Step 3: Persist ───────────────────────────────────────────────────
    if (!_active) return;
    state = ScanSaving(processed: processed, pattern: pattern);

    // 3a — Ensure soldier row (idempotent, failure is non-fatal).
    final soldierResult = await ref
        .read(soldierRepositoryProvider)
        .upsertSoldier(Soldier(id: arg.soldierId));

    if (soldierResult.isFailure) {
      AppLogger.w(
        'ScanFlow: upsertSoldier failed — '
        '${soldierResult.failureOrNull!.message}',
      );
    }

    // 3b — Insert shot record.
    final analysedShot = pattern.shots.firstOrNull;
    final record = ShotRecord(
      soldierId: arg.soldierId,
      x: processed.normalisedOffsetX,
      y: processed.normalisedOffsetY,
      distance: analysedShot?.distance ?? 0.0,
      angle: analysedShot?.angleDeg ?? 0.0,
      pattern: pattern.pattern.name,
      errorType: pattern.error?.name,
      createdAt: DateTime.now().toUtc(),
    );

    final saveResult =
        await ref.read(saveShotRecordsUseCaseProvider)([record]);
    if (!_active) return;

    String? saveWarning;
    if (saveResult.isFailure) {
      saveWarning = saveResult.failureOrNull!.message;
      AppLogger.w('ScanFlow: shot record save failed — $saveWarning');
    } else {
      // Invalidate the shot history so any listener sees fresh data.
      ref.invalidate(shotHistoryProvider(arg.soldierId));
    }

    // ── Step 4: Decode native image size ──────────────────────────────────
    if (!_active) return;
    final nativeSize = await _decodeImageSize(processed.processedPath);
    if (!_active) return;

    // ── Step 5: Audio feedback ────────────────────────────────────────────
    if (pattern.error != null) {
      ref.read(audioProvider.notifier).playErrorSound(pattern.error!);
    }

    AppLogger.d(
      'ScanFlow complete: soldier=${arg.soldierId} '
      'pattern=${pattern.pattern.name} error=${pattern.error?.name} '
      'saved=${saveWarning == null}',
    );

    state = ScanComplete(
      processed: processed,
      pattern: pattern,
      nativeImageSize: nativeSize,
      saveWarning: saveWarning,
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Resets state and reruns the pipeline from step 1.
  Future<void> retry() async {
    _active = true;
    await _execute();
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  static Future<Size> _decodeImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
  }
}

final scanFlowProvider = NotifierProvider.family<ScanFlowNotifier,
    ScanFlowState, ScanArgs>(
  ScanFlowNotifier.new,
);
