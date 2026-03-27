import 'package:camera/camera.dart';

import '../../../../core/utils/logger.dart';
import '../models/captured_image_model.dart';

/// Wraps the `camera` package.  Operates with raw file paths and camera types.
class CameraDatasource {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool get isInitialised => _controller?.value.isInitialized ?? false;

  CameraController? get controller => _controller;

  Future<void> initialise() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw StateError('No cameras available.');

    // Prefer back camera.
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    AppLogger.i('Camera initialised: ${camera.name}');
  }

  Future<CapturedImageModel> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw StateError('Camera not initialised.');
    }
    final file = await _controller!.takePicture();
    AppLogger.d('Image captured: ${file.path}');
    return CapturedImageModel(
      path: file.path,
      capturedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> setZoomLevel(double zoom) async {
    final minZoom = await _controller!.getMinZoomLevel();
    final maxZoom = await _controller!.getMaxZoomLevel();
    final clamped = zoom.clamp(minZoom, maxZoom);
    await _controller!.setZoomLevel(clamped);
  }

  Future<void> setFlashMode(bool enabled) async {
    await _controller!.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    AppLogger.d('Camera disposed.');
  }
}
