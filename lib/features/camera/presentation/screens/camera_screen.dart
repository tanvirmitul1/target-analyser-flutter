import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialise camera after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialise();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      ref.read(cameraProvider.notifier).disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initialise();
    }
  }

  Future<void> _onCapture() async {
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

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Capture Target'),
        actions: [
          IconButton(
            icon: Icon(
              cameraState.flashEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () => ref.read(cameraProvider.notifier).toggleFlash(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CameraPreviewWidget(cameraState: cameraState),
          ),
          _ZoomSlider(
            zoom: cameraState.zoom,
            onChanged: (v) => ref.read(cameraProvider.notifier).setZoom(v),
          ),
          const SizedBox(height: 16),
          CaptureButton(
            isCapturing: cameraState.status == CameraStatus.capturing,
            isReady: cameraState.isReady,
            onCapture: _onCapture,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.zoom, required this.onChanged});
  final double zoom;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.zoom_out, color: Colors.white),
          Expanded(
            child: Slider(
              value: zoom,
              min: 1,
              max: 8,
              divisions: 14,
              label: '${zoom.toStringAsFixed(1)}x',
              onChanged: onChanged,
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white),
        ],
      ),
    );
  }
}
