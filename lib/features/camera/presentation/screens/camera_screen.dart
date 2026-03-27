import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../result/presentation/screens/result_screen.dart';
import '../providers/camera_provider.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/capture_button.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({required this.soldierId, super.key});
  final String soldierId;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  double _pinchBaseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(cameraProvider.notifier).start(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    if (details.pointerCount < 2) return;
    final cs = ref.read(cameraProvider);
    final newZoom =
        (_pinchBaseZoom * details.scale).clamp(cs.minZoom, cs.maxZoom);
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
          builder: (_) => ResultScreen(
            imagePath: image.path,
            soldierId: widget.soldierId,
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

  AppBar _buildAppBar(CameraState cameraState) => AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.soldierId,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (cameraState.isReady)
            IconButton(
              icon: Icon(
                cameraState.flashEnabled ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () =>
                  ref.read(cameraProvider.notifier).toggleFlash(),
            ),
        ],
      );

  Widget _buildBody(CameraState cameraState) {
    if (cameraState.status == CameraStatus.permissionDenied) {
      return _PermissionView(
        isPermanent: false,
        onRetry: () => ref.read(cameraProvider.notifier).start(),
      );
    }
    if (cameraState.status == CameraStatus.permissionPermanentlyDenied) {
      return _PermissionView(
        isPermanent: true,
        onOpenSettings: () =>
            ref.read(cameraProvider.notifier).openPermissionSettings(),
      );
    }
    if (cameraState.hasError) {
      return _ErrorView(
        message: cameraState.errorMessage ?? 'Unknown camera error.',
        onRetry: () => ref.read(cameraProvider.notifier).start(),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildPreview(cameraState)),
        _buildControls(cameraState),
      ],
    );
  }

  Widget _buildPreview(CameraState cameraState) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onTapDown: (d) => _onTapDown(d, constraints),
          child: CameraPreviewWidget(
            cameraState: cameraState,
            constraints: constraints,
          ),
        ),
      );

  Widget _buildControls(CameraState cameraState) => ColoredBox(
        color: Colors.black,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cameraState.isReady) ...[
                  _ZoomSlider(
                    zoom: cameraState.zoom,
                    minZoom: cameraState.minZoom,
                    maxZoom: cameraState.maxZoom,
                    onChanged: (v) =>
                        ref.read(cameraProvider.notifier).setZoom(v),
                  ),
                  const SizedBox(height: 12),
                ],
                CaptureButton(
                  isCapturing: cameraState.isCapturing,
                  isReady: cameraState.isReady,
                  onCapture: _capture,
                ),
                const SizedBox(height: 8),
                Text(
                  cameraState.isReady ? 'Tap to focus  •  Pinch to zoom' : '',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({
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
          const Icon(Icons.zoom_out, color: Colors.white54, size: 18),
          Expanded(
            child: Slider(
              value: zoom.clamp(minZoom, maxZoom),
              min: minZoom,
              max: maxZoom,
              divisions: maxZoom > minZoom
                  ? ((maxZoom - minZoom) * 4).round().clamp(1, 60)
                  : null,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white54, size: 18),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              '${zoom.toStringAsFixed(1)}×',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
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
            const Icon(Icons.no_photography, size: 56, color: Colors.white38),
            const SizedBox(height: 20),
            Text(
              isPermanent
                  ? 'Camera permission permanently denied.\nOpen Settings to enable it.'
                  : 'Camera access is required to capture targets.',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: isPermanent ? onOpenSettings : onRetry,
              icon: Icon(isPermanent ? Icons.settings : Icons.camera_alt),
              label: Text(isPermanent ? 'Open Settings' : 'Grant Permission'),
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
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white60),
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
