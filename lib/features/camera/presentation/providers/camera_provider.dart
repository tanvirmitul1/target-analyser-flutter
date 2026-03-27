import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../data/datasources/camera_datasource.dart';
import '../../data/repositories/camera_repository_impl.dart';
import '../../domain/entities/captured_image.dart';
import '../../domain/repositories/camera_repository.dart';
import '../../domain/usecases/capture_image_usecase.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final cameraDatasourceProvider = Provider<CameraDatasource>(
  (ref) => CameraDatasource(),
);

final cameraRepositoryProvider = Provider<CameraRepository>(
  (ref) => CameraRepositoryImpl(ref.watch(cameraDatasourceProvider)),
);

final captureImageUseCaseProvider = Provider<CaptureImageUseCase>(
  (ref) => CaptureImageUseCase(ref.watch(cameraRepositoryProvider)),
);

// ── Camera controller access (for CameraPreview widget) ───────────────────────

final cameraControllerProvider = Provider<CameraController?>((ref) {
  final ds = ref.watch(cameraDatasourceProvider);
  return ds.controller;
});

// ── Camera state notifier ─────────────────────────────────────────────────────

enum CameraStatus { uninitialised, initialising, ready, capturing, error }

class CameraState {
  const CameraState({
    this.status = CameraStatus.uninitialised,
    this.lastCapture,
    this.errorMessage,
    this.zoom = 1.0,
    this.flashEnabled = false,
  });

  final CameraStatus status;
  final CapturedImage? lastCapture;
  final String? errorMessage;
  final double zoom;
  final bool flashEnabled;

  bool get isReady => status == CameraStatus.ready;

  CameraState copyWith({
    CameraStatus? status,
    CapturedImage? lastCapture,
    String? errorMessage,
    double? zoom,
    bool? flashEnabled,
  }) =>
      CameraState(
        status: status ?? this.status,
        lastCapture: lastCapture ?? this.lastCapture,
        errorMessage: errorMessage ?? this.errorMessage,
        zoom: zoom ?? this.zoom,
        flashEnabled: flashEnabled ?? this.flashEnabled,
      );
}

class CameraNotifier extends Notifier<CameraState> {
  @override
  CameraState build() => const CameraState();

  CameraRepository get _repo => ref.read(cameraRepositoryProvider);

  Future<void> initialise() async {
    state = state.copyWith(status: CameraStatus.initialising);
    final result = await _repo.initialise();
    result.when(
      onSuccess: (_) => state = state.copyWith(status: CameraStatus.ready),
      onFailure: (f) => state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: f.message,
      ),
    );
  }

  Future<Result<CapturedImage>> capture() async {
    state = state.copyWith(status: CameraStatus.capturing);
    final result = await ref.read(captureImageUseCaseProvider)();
    result.when(
      onSuccess: (img) => state = state.copyWith(
        status: CameraStatus.ready,
        lastCapture: img,
      ),
      onFailure: (f) => state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: f.message,
      ),
    );
    return result;
  }

  Future<void> setZoom(double zoom) async {
    final result = await _repo.setZoomLevel(zoom);
    if (result.isSuccess) state = state.copyWith(zoom: zoom);
  }

  Future<void> toggleFlash() async {
    final next = !state.flashEnabled;
    final result = await _repo.setFlashMode(next);
    if (result.isSuccess) state = state.copyWith(flashEnabled: next);
  }

  Future<void> disposeCamera() async {
    await _repo.dispose();
    state = const CameraState();
  }
}

final cameraProvider = NotifierProvider<CameraNotifier, CameraState>(
  CameraNotifier.new,
);
