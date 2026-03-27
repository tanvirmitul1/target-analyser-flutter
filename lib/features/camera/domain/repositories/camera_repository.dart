import '../../../../core/utils/result.dart';
import '../entities/captured_image.dart';

abstract interface class CameraRepository {
  Future<Result<void>> initialise();
  Future<Result<CapturedImage>> captureImage();
  Future<Result<void>> dispose();
  Future<Result<void>> setZoomLevel(double zoom);
  Future<Result<void>> setFlashMode(bool enabled);
  Future<Result<void>> setFocusPoint(double x, double y);
}
