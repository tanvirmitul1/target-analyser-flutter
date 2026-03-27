import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../storage/presentation/providers/storage_provider.dart';
import '../../data/datasources/analysis_datasource.dart';
import '../../data/models/analysis_input.dart';
import '../../data/repositories/analysis_repository_impl.dart';
import '../../domain/entities/shot_result.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../../domain/usecases/analyse_target_usecase.dart';
import '../../../processing/domain/entities/processed_image.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final analysisDatasourceProvider = Provider<AnalysisDatasource>(
  (ref) => AnalysisDatasource(),
);

final analysisRepositoryProvider = Provider<AnalysisRepository>(
  (ref) => AnalysisRepositoryImpl(ref.watch(analysisDatasourceProvider)),
);

final analyseTargetUseCaseProvider = Provider<AnalyseTargetUseCase>(
  (ref) => AnalyseTargetUseCase(ref.watch(analysisRepositoryProvider)),
);

// ── Analysis notifier ─────────────────────────────────────────────────────────

class AnalysisState {
  const AnalysisState({
    this.isLoading = false,
    this.latestShot,
    this.error,
  });

  final bool isLoading;
  final ShotResult? latestShot;
  final String? error;

  bool get hasResult => latestShot != null;

  AnalysisState copyWith({
    bool? isLoading,
    ShotResult? latestShot,
    String? error,
  }) =>
      AnalysisState(
        isLoading: isLoading ?? this.isLoading,
        latestShot: latestShot ?? this.latestShot,
        error: error ?? this.error,
      );
}

class AnalysisNotifier extends Notifier<AnalysisState> {
  @override
  AnalysisState build() => const AnalysisState();

  Future<Result<ShotResult>> analyseAndSave({
    required ProcessedImage processedImage,
    required String sessionId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final input = AnalysisInput(
      sessionId: sessionId,
      imagePath: processedImage.originalPath,
      processedImagePath: processedImage.processedPath,
      normalisedOffsetX: processedImage.normalisedOffsetX,
      normalisedOffsetY: processedImage.normalisedOffsetY,
      timestamp: processedImage.processedAt,
    );

    final result = await ref.read(analyseTargetUseCaseProvider)(input);

    result.when(
      onSuccess: (shot) async {
        state = state.copyWith(isLoading: false, latestShot: shot);
        // Persist to storage.
        await ref.read(sessionListProvider.notifier).addShot(shot);
      },
      onFailure: (f) => state = state.copyWith(
        isLoading: false,
        error: f.message,
      ),
    );

    return result;
  }

  void reset() => state = const AnalysisState();
}

final analysisProvider = NotifierProvider<AnalysisNotifier, AnalysisState>(
  AnalysisNotifier.new,
);
