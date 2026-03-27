import '../../../../core/utils/result.dart';
import '../../domain/entities/captured_image.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/camera_datasource.dart';

class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl(this._datasource);
  final CameraDatasource _datasource;

  @override
  Future<Result<void>> initialise() => guard(
        () => _datasource.initialise(),
        onError: (e, st) => CameraFailure('Failed to initialise camera.', cause: e),
      );

  @override
  Future<Result<CapturedImage>> captureImage() => guard(
        () async {
          final model = await _datasource.captureImage();
          return model.toDomain();
        },
        onError: (e, st) => CameraFailure('Failed to capture image.', cause: e),
      );

  @override
  Future<Result<void>> dispose() => guard(
        () => _datasource.dispose(),
        onError: (e, st) => CameraFailure('Failed to dispose camera.', cause: e),
      );

  @override
  Future<Result<void>> setZoomLevel(double zoom) => guard(
        () => _datasource.setZoomLevel(zoom),
        onError: (e, st) => CameraFailure('Failed to set zoom.', cause: e),
      );

  @override
  Future<Result<void>> setFlashMode(bool enabled) => guard(
        () => _datasource.setFlashMode(enabled),
        onError: (e, st) => CameraFailure('Failed to set flash.', cause: e),
      );
}
