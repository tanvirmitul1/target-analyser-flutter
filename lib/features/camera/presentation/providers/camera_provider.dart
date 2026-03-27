import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/camera_datasource.dart';
import '../../data/repositories/camera_repository_impl.dart';
import '../../data/services/camera_permission_service.dart';
import '../../domain/entities/captured_image.dart';
import '../../domain/repositories/camera_repository.dart';
import '../../domain/usecases/capture_image_usecase.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final cameraDatasourceProvider = Provider<CameraDatasource>(
  (ref) => CameraDatasource(),
);

final cameraPermissionServiceProvider = Provider<CameraPermissionService>(
  (ref) => const CameraPermissionService(),
);

final cameraRepositoryProvider = Provider<CameraRepository>(
  (ref) => CameraRepositoryImpl(ref.watch(cameraDatasourceProvider)),
);

final captureImageUseCaseProvider = Provider<CaptureImageUseCase>(
  (ref) => CaptureImageUseCase(ref.watch(cameraRepositoryProvider)),
);

// ── Controller access (for the CameraPreview widget) ─────────────────────────

/// Exposes the raw [CameraController] so [CameraPreview] can render frames.
final cameraControllerProvider = Provider<CameraController?>((ref) {
  return ref.watch(cameraDatasourceProvider).controller;
});

// ── State ─────────────────────────────────────────────────────────────────────

enum CameraStatus {
  uninitialised,
  checkingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  initialising,
  ready,
  capturing,
  error,
}

class CameraState {
  const CameraState({
    this.status = CameraStatus.uninitialised,
    this.lastCapture,
    this.errorMessage,
    this.zoom = 1.0,
    this.minZoom = 1.0,
    this.maxZoom = 8.0,
    this.flashEnabled = false,
    this.focusPoint,
  });

  final CameraStatus status;
  final CapturedImage? lastCapture;
  final String? errorMessage;

  /// Current zoom level (set by user).
  final double zoom;

  /// Device-reported minimum zoom — valid after initialisation.
  final double minZoom;

  /// Device-reported maximum zoom — valid after initialisation.
  final double maxZoom;

  final bool flashEnabled;

  /// Normalised (0–1) tap-to-focus point, null when not in use.
  final Offset? focusPoint;

  bool get isReady => status == CameraStatus.ready;
  bool get isCapturing => status == CameraStatus.capturing;
  bool get hasError => status == CameraStatus.error;

  bool get permissionDenied =>
      status == CameraStatus.permissionDenied ||
      status == CameraStatus.permissionPermanentlyDenied;

  CameraState copyWith({
    CameraStatus? status,
    CapturedImage? lastCapture,
    String? errorMessage,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    bool? flashEnabled,
    Offset? focusPoint,
    bool clearFocusPoint = false,
    bool clearError = false,
    bool clearCapture = false,
  }) =>
      CameraState(
        status: status ?? this.status,
        lastCapture: clearCapture ? null : (lastCapture ?? this.lastCapture),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        zoom: zoom ?? this.zoom,
        minZoom: minZoom ?? this.minZoom,
        maxZoom: maxZoom ?? this.maxZoom,
        flashEnabled: flashEnabled ?? this.flashEnabled,
        focusPoint: clearFocusPoint ? null : (focusPoint ?? this.focusPoint),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CameraNotifier extends Notifier<CameraState> {
  @override
  CameraState build() => const CameraState();

  CameraRepository get _repo => ref.read(cameraRepositoryProvider);
  CameraDatasource get _ds => ref.read(cameraDatasourceProvider);
  CameraPermissionService get _permSvc =>
      ref.read(cameraPermissionServiceProvider);

  // Track whether we disposed because of an app-lifecycle pause (not user
  // navigation), so [didResume] knows whether to reinitialise.
  bool _pausedForLifecycle = false;

  // ── Entry point ───────────────────────────────────────────────────────────

  /// Check permission then initialise.  Safe to call multiple times — guards
  /// against double-init internally.
  Future<void> start() async {
    if (state.isReady || state.status == CameraStatus.initialising) return;

    state = state.copyWith(
      status: CameraStatus.checkingPermission,
      clearError: true,
    );

    final permStatus = await _permSvc.request();

    switch (permStatus) {
      case CameraPermissionStatus.granted:
        await _initialise();
      case CameraPermissionStatus.denied:
        state = state.copyWith(status: CameraStatus.permissionDenied);
      case CameraPermissionStatus.permanentlyDenied:
        state = state.copyWith(
          status: CameraStatus.permissionPermanentlyDenied,
        );
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called by the screen when [AppLifecycleState.paused] fires.
  Future<void> didPause() async {
    if (!state.isReady && !state.isCapturing) return;
    _pausedForLifecycle = true;
    AppLogger.d('Camera: pausing for lifecycle.');
    await _repo.dispose();
    state = const CameraState();
  }

  /// Called by the screen when [AppLifecycleState.resumed] fires.
  Future<void> didResume() async {
    if (!_pausedForLifecycle) return;
    _pausedForLifecycle = false;
    AppLogger.d('Camera: resuming after lifecycle pause.');
    await start();
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<Result<CapturedImage>> capture() async {
    if (!state.isReady) return const Failure(CameraFailure('Camera not ready.'));

    state = state.copyWith(status: CameraStatus.capturing, clearError: true);
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
    if (!state.isReady) return;
    final result = await _repo.setZoomLevel(zoom);
    if (result.isSuccess) state = state.copyWith(zoom: zoom);
  }

  Future<void> toggleFlash() async {
    if (!state.isReady) return;
    final next = !state.flashEnabled;
    final result = await _repo.setFlashMode(next);
    if (result.isSuccess) state = state.copyWith(flashEnabled: next);
  }

  /// [x], [y] are normalised coordinates in [0.0, 1.0].
  Future<void> setFocusPoint(double x, double y) async {
    if (!state.isReady) return;
    state = state.copyWith(focusPoint: Offset(x, y));
    try {
      await _ds.setFocusPoint(x, y);
    } catch (e) {
      AppLogger.w('setFocusPoint failed', error: e);
    }
    // Clear focus indicator after a short delay.
    await Future<void>.delayed(const Duration(seconds: 2));
    state = state.copyWith(clearFocusPoint: true);
  }

  Future<void> openPermissionSettings() => _permSvc.openSettings();

  Future<void> disposeCamera() async {
    _pausedForLifecycle = false;
    await _repo.dispose();
    state = const CameraState();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _initialise() async {
    state = state.copyWith(status: CameraStatus.initialising, clearError: true);
    final result = await _repo.initialise();
    result.when(
      onSuccess: (_) => state = state.copyWith(
        status: CameraStatus.ready,
        minZoom: _ds.minZoom,
        maxZoom: _ds.maxZoom,
        zoom: _ds.minZoom,
      ),
      onFailure: (f) => state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: f.message,
      ),
    );
  }
}

final cameraProvider = NotifierProvider<CameraNotifier, CameraState>(
  CameraNotifier.new,
);
