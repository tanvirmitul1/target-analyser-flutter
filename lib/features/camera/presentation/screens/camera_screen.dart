import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../processing/presentation/screens/processing_screen.dart';
import '../providers/camera_provider.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/capture_button.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  // Baseline zoom when a pinch gesture starts.
  double _pinchBaseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Force portrait while the camera screen is active.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Start permission-check + initialisation after the first frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(cameraProvider.notifier).start(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore the app-level orientation list (set in main.dart).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Use paused (not inactive) — inactive is transient (e.g. during
    // notification shade open) and should not trigger disposal.
    switch (state) {
      case AppLifecycleState.paused:
        ref.read(cameraProvider.notifier).didPause();
      case AppLifecycleState.resumed:
        ref.read(cameraProvider.notifier).didResume();
      default:
        break;
    }
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails _) {
    _pinchBaseZoom = ref.read(cameraProvider).zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return; // only react to pinch (2 fingers)
    final cameraState = ref.read(cameraProvider);
    final newZoom = (_pinchBaseZoom * details.scale)
        .clamp(cameraState.minZoom, cameraState.maxZoom);
    ref.read(cameraProvider.notifier).setZoom(newZoom);
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;
    ref.read(cameraProvider.notifier).setFocusPoint(x, y);
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    final result = await ref.read(cameraProvider.notifier).capture();
    if (!mounted) return;
    result.when(
      onSuccess: (image) => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingScreen(
            imagePath: image.path,
            sessionId: widget.sessionId,
          ),
        ),
      ),
      onFailure: (f) => context.showSnackBar(f.message, isError: true),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(cameraState),
      body: _buildBody(cameraState),
    );
  }

  AppBar _buildAppBar(CameraState cameraState) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Capture Target'),
      actions: [
        if (cameraState.isReady)
          IconButton(
            icon: Icon(
              cameraState.flashEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            tooltip: cameraState.flashEnabled ? 'Flash off' : 'Flash on',
            onPressed: () => ref.read(cameraProvider.notifier).toggleFlash(),
          ),
      ],
    );
  }

  Widget _buildBody(CameraState cameraState) {
    // ── Permission denied ────────────────────────────────────────────────────
    if (cameraState.status == CameraStatus.permissionDenied) {
      return _PermissionDeniedView(
        isPermanent: false,
        onRetry: () => ref.read(cameraProvider.notifier).start(),
      );
    }
    if (cameraState.status == CameraStatus.permissionPermanentlyDenied) {
      return _PermissionDeniedView(
        isPermanent: true,
        onOpenSettings: () =>
            ref.read(cameraProvider.notifier).openPermissionSettings(),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (cameraState.hasError) {
      return _ErrorView(
        message: cameraState.errorMessage ?? 'Unknown camera error.',
        onRetry: () => ref.read(cameraProvider.notifier).start(),
      );
    }

    // ── Loading / preview ────────────────────────────────────────────────────
    return Column(
      children: [
        Expanded(
          child: _buildPreviewArea(cameraState),
        ),
        _buildControls(cameraState),
      ],
    );
  }

  Widget _buildPreviewArea(CameraState cameraState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Pinch-to-zoom
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          // Tap-to-focus
          onTapDown: (d) => _onTapDown(d, constraints),
          child: CameraPreviewWidget(
            cameraState: cameraState,
            constraints: constraints,
          ),
        );
      },
    );
  }

  Widget _buildControls(CameraState cameraState) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cameraState.isReady)
                _ZoomControls(
                  zoom: cameraState.zoom,
                  minZoom: cameraState.minZoom,
                  maxZoom: cameraState.maxZoom,
                  onChanged: (v) =>
                      ref.read(cameraProvider.notifier).setZoom(v),
                ),
              const SizedBox(height: 16),
              CaptureButton(
                isCapturing: cameraState.isCapturing,
                isReady: cameraState.isReady,
                onCapture: _capture,
              ),
              const SizedBox(height: 8),
              Text(
                cameraState.isReady
                    ? 'Tap to focus  •  Pinch to zoom'
                    : '',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onChanged,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
          Expanded(
            child: Slider(
              value: zoom.clamp(minZoom, maxZoom),
              min: minZoom,
              max: maxZoom,
              divisions: maxZoom > minZoom
                  ? ((maxZoom - minZoom) * 4).round().clamp(1, 60)
                  : null,
              label: '${zoom.toStringAsFixed(1)}×',
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${zoom.toStringAsFixed(1)}×',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.isPermanent,
    this.onRetry,
    this.onOpenSettings,
  });

  final bool isPermanent;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            Text(
              isPermanent
                  ? 'Camera permission was permanently denied.'
                  : 'Camera permission is required to capture targets.',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (isPermanent)
              const Text(
                'Please open Settings and enable the Camera permission for this app.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            if (isPermanent)
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Grant Permission'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
