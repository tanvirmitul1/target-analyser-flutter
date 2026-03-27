import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../storage/presentation/providers/storage_provider.dart';
import '../../data/repositories/shot_pattern_repository_impl.dart';
import '../../data/services/shot_analysis_service.dart';
import '../../domain/entities/shot_pattern.dart';
import '../../domain/repositories/shot_pattern_repository.dart';
import '../../domain/usecases/analyse_shot_pattern_usecase.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final shotAnalysisServiceProvider = Provider<ShotAnalysisService>(
  (ref) => const ShotAnalysisService(),
);

final shotPatternRepositoryProvider = Provider<ShotPatternRepository>(
  (ref) => ShotPatternRepositoryImpl(ref.watch(shotAnalysisServiceProvider)),
);

final analyseShotPatternUseCaseProvider = Provider<AnalyseShotPatternUseCase>(
  (ref) => AnalyseShotPatternUseCase(ref.watch(shotPatternRepositoryProvider)),
);

// ── Reactive pattern provider ─────────────────────────────────────────────────

/// Watches the session identified by [sessionId] and re-runs the analysis
/// whenever a new shot is added (because [sessionListProvider] invalidates).
///
/// The target centre is always (0, 0) — shots are stored as normalised offsets
/// from centre, so no coordinate translation is needed.
final shotPatternProvider =
    FutureProvider.family<ShotPattern, String>((ref, sessionId) async {
  final sessionAsync = await ref.watch(
    sessionByIdProvider(sessionId).future,
  );

  if (sessionAsync == null || sessionAsync.shots.isEmpty) {
    return const ShotPattern.empty();
  }

  const center = (x: 0.0, y: 0.0);

  final shotPoints = sessionAsync.shots
      .map<ShotPoint>((s) => (x: s.offsetX, y: s.offsetY))
      .toList(growable: false);

  final result = await ref.read(analyseShotPatternUseCaseProvider)(
    center: center,
    shots: shotPoints,
  );

  return result.when(
    onSuccess: (pattern) => pattern,
    onFailure: (f) => throw Exception(f.message),
  );
});

// ── Manual trigger (for single-shot update without rebuilding whole session) ──

class ShotPatternNotifier extends AsyncNotifier<ShotPattern> {
  @override
  Future<ShotPattern> build() async => const ShotPattern.empty();

  /// Runs the analysis synchronously against [center] + [shots] and updates
  /// state.  Useful when the caller has already resolved the coordinate list
  /// (e.g. right after processing a new image).
  Future<Result<ShotPattern>> run({
    required ShotPoint center,
    required List<ShotPoint> shots,
  }) async {
    state = const AsyncValue.loading();

    final result = await ref.read(analyseShotPatternUseCaseProvider)(
      center: center,
      shots: shots,
    );

    state = result.when(
      onSuccess: AsyncValue.data,
      onFailure: (f) => AsyncValue.error(f, StackTrace.current),
    );

    return result;
  }
}

final shotPatternNotifierProvider =
    AsyncNotifierProvider<ShotPatternNotifier, ShotPattern>(
  ShotPatternNotifier.new,
);
