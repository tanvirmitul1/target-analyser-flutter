import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/image_processing_datasource.dart';
import '../../data/repositories/processing_repository_impl.dart';
import '../../domain/entities/processed_image.dart';
import '../../domain/repositories/processing_repository.dart';
import '../../domain/usecases/process_image_usecase.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final imageProcessingDatasourceProvider = Provider<ImageProcessingDatasource>(
  (ref) => ImageProcessingDatasource(),
);

final processingRepositoryProvider = Provider<ProcessingRepository>(
  (ref) => ProcessingRepositoryImpl(ref.watch(imageProcessingDatasourceProvider)),
);

final processImageUseCaseProvider = Provider<ProcessImageUseCase>(
  (ref) => ProcessImageUseCase(ref.watch(processingRepositoryProvider)),
);

// ── Processing state ──────────────────────────────────────────────────────────

class ProcessingNotifier extends FamilyAsyncNotifier<ProcessedImage, String> {
  @override
  Future<ProcessedImage> build(String imagePath) => _process(imagePath);

  Future<ProcessedImage> _process(String imagePath) async {
    final result = await ref.read(processImageUseCaseProvider)(imagePath);
    return result.when(
      onSuccess: (img) => img,
      onFailure: (f) => throw Exception(f.message),
    );
  }

  Future<void> retry(String imagePath) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _process(imagePath));
  }
}

final processingProvider = AsyncNotifierProviderFamily<ProcessingNotifier,
    ProcessedImage, String>(ProcessingNotifier.new);
