import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/logger.dart';
import '../models/captured_image_model.dart';

/// Low-level camera service wrapping the `camera` package.
///
/// Lifecycle contract (must be respected by callers):
///   1. Call [initialise] once before any other method.
///   2. Call [dispose] when the camera is no longer needed.
///   3. May call [initialise] again after [dispose] (lifecycle resume).
class CameraDatasource {
  CameraController? _controller;

  // Cached limits — populated during initialise, valid until dispose.
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  // ── Accessors ──────────────────────────────────────────────────────────────

  bool get isInitialised => _controller?.value.isInitialized ?? false;
  CameraController? get controller => _controller;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentZoom => _currentZoom;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Selects back camera, initialises at [ResolutionPreset.veryHigh], locks
  /// capture orientation to portrait-up, and caches zoom limits.
  Future<void> initialise() async {
    if (_controller != null) {
      AppLogger.w('CameraDatasource.initialise() called while already active — disposing first.');
      await dispose();
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No cameras found on this device.');

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.veryHigh, // highest JPEG quality available
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();

    // Lock EXIF orientation so the saved file is always portrait-up.
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    // Cache zoom range for this device.
    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _currentZoom = _minZoom;

    AppLogger.i(
      'Camera ready: ${camera.name} | '
      'zoom [$_minZoom–$_maxZoom] | '
      'resolution: veryHigh',
    );
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _minZoom = 1.0;
    _maxZoom = 1.0;
    _currentZoom = 1.0;
    AppLogger.d('Camera disposed.');
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  /// Captures a JPEG and stores it in the app's temp directory (not gallery).
  Future<CapturedImageModel> captureImage() async {
    _assertInitialised('captureImage');
    final file = await _controller!.takePicture();
    AppLogger.d('Image captured → ${file.path}');
    return CapturedImageModel(
      path: file.path,
      capturedAt: DateTime.now().toIso8601String(),
    );
  }

  // ── Camera controls ────────────────────────────────────────────────────────

  Future<void> setZoomLevel(double zoom) async {
    _assertInitialised('setZoomLevel');
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clamped);
    _currentZoom = clamped;
  }

  Future<void> setFlashMode(bool enabled) async {
    _assertInitialised('setFlashMode');
    await _controller!
        .setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
  }

  /// Sets the focus and exposure point.
  ///
  /// [x] and [y] are normalised coordinates in [0.0, 1.0], relative to
  /// the preview dimensions (origin = top-left).
  Future<void> setFocusPoint(double x, double y) async {
    _assertInitialised('setFocusPoint');
    final controller = _controller!;

    if (controller.value.focusPointSupported) {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(Offset(x, y));
    }
    if (controller.value.exposurePointSupported) {
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setExposurePoint(Offset(x, y));
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _assertInitialised(String caller) {
    if (!isInitialised) {
      throw StateError('CameraDatasource.$caller() called before initialise().');
    }
  }
}
