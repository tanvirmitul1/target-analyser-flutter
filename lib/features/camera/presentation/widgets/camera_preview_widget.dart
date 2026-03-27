import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/camera_provider.dart';

class CameraPreviewWidget extends ConsumerWidget {
  const CameraPreviewWidget({required this.cameraState, super.key});
  final CameraState cameraState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cameraState.status == CameraStatus.error) {
      return Center(
        child: Text(
          cameraState.errorMessage ?? 'Camera error',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (cameraState.status == CameraStatus.uninitialised ||
        cameraState.status == CameraStatus.initialising) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final controller = ref.watch(cameraControllerProvider);
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        // Targeting overlay
        CustomPaint(painter: _TargetOverlayPainter()),
      ],
    );
  }
}

class _TargetOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Draw guide circles.
    for (final factor in [0.2, 0.4, 0.6, 0.8, 1.0]) {
      canvas.drawCircle(centre, radius * factor, paint);
    }

    // Draw crosshairs.
    canvas.drawLine(
      centre.translate(-radius, 0),
      centre.translate(radius, 0),
      paint,
    );
    canvas.drawLine(
      centre.translate(0, -radius),
      centre.translate(0, radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
