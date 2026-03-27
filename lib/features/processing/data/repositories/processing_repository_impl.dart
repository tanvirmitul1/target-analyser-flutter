import '../../../../core/utils/result.dart';
import '../../domain/entities/processed_image.dart';
import '../../domain/repositories/processing_repository.dart';
import '../datasources/base_processing_datasource.dart';

class ProcessingRepositoryImpl implements ProcessingRepository {
  const ProcessingRepositoryImpl(this._datasource);
  final BaseProcessingDatasource _datasource;

  @override
  Future<Result<ProcessedImage>> processImage(String imagePath) => guard(
        () async {
          final model = await _datasource.processImage(imagePath);
          return model.toDomain();
        },
        onError: (e, st) =>
            ProcessingFailure('Failed to process image.', cause: e),
      );
}
