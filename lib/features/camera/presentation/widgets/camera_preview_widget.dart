import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/camera_provider.dart';

/// Full-area camera preview with animated target overlay.
///
/// Renders one of three states:
///   - Loading spinner (uninitialised / initialising)
///   - Live preview  + animated crosshair + optional focus indicator
///   - Error text (handled by the parent screen — this widget won't receive it)
class CameraPreviewWidget extends ConsumerStatefulWidget {
  const CameraPreviewWidget({
    required this.cameraState,
    required this.constraints,
    super.key,
  });

  final CameraState cameraState;
  final BoxConstraints constraints;

  @override
  ConsumerState<CameraPreviewWidget> createState() =>
      _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends ConsumerState<CameraPreviewWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = widget.cameraState;

    // ── Loading ────────────────────────────────────────────────────────────
    if (cameraState.status == CameraStatus.uninitialised ||
        cameraState.status == CameraStatus.initialising ||
        cameraState.status == CameraStatus.checkingPermission) {
      return const _LoadingView();
    }

    final controller = ref.watch(cameraControllerProvider);
    if (controller == null || !controller.value.isInitialized) {
      return const _LoadingView();
    }

    // ── Live preview ───────────────────────────────────────────────────────
    return Stack(
      fit: StackFit.expand,
      children: [
        // Scale preview to fill the available area without distortion.
        _ScaledCameraPreview(controller: controller),

        // Static target ring overlay.
        CustomPaint(
          painter: _TargetRingsPainter(),
        ),

        // Animated crosshair + pulsing centre dot.
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) => CustomPaint(
            painter: _CrosshairPainter(pulse: _pulseAnim.value),
          ),
        ),

        // Tap-to-focus indicator.
        if (cameraState.focusPoint != null)
          _FocusIndicator(
            normalisedOffset: cameraState.focusPoint!,
            constraints: widget.constraints,
          ),

        // Capturing flash overlay.
        if (cameraState.isCapturing)
          const ColoredBox(color: Color(0x44FFFFFF)),
      ],
    );
  }
}

// ── Scaled preview ─────────────────────────────────────────────────────────────

class _ScaledCameraPreview extends StatelessWidget {
  const _ScaledCameraPreview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    // CameraPreview constrains its aspect ratio to the sensor ratio.  We wrap
    // it in a FittedBox so it fills the available area (cropping if needed).
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

// ── Loading view ───────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initialising camera…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Focus indicator ────────────────────────────────────────────────────────────

class _FocusIndicator extends StatefulWidget {
  const _FocusIndicator({
    required this.normalisedOffset,
    required this.constraints,
  });

  final Offset normalisedOffset;
  final BoxConstraints constraints;

  @override
  State<_FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<_FocusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sizeAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sizeAnim = Tween<double>(begin: 70, end: 44).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 1, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.normalisedOffset.dx * widget.constraints.maxWidth;
    final y = widget.normalisedOffset.dy * widget.constraints.maxHeight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final size = _sizeAnim.value;
        return Positioned(
          left: x - size / 2,
          top: y - size / 2,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(painter: _FocusSquarePainter()),
            ),
          ),
        );
      },
    );
  }
}

class _FocusSquarePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const cornerLen = 10.0;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw corner brackets instead of a full rectangle.
    for (final corner in [
      (r.topLeft, const Offset(cornerLen, 0), const Offset(0, cornerLen)),
      (r.topRight, const Offset(-cornerLen, 0), const Offset(0, cornerLen)),
      (r.bottomLeft, const Offset(cornerLen, 0), const Offset(0, -cornerLen)),
      (r.bottomRight, const Offset(-cornerLen, 0), const Offset(0, -cornerLen)),
    ]) {
      canvas
        ..drawLine(corner.$1, corner.$1 + corner.$2, paint)
        ..drawLine(corner.$1, corner.$1 + corner.$3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Target overlay painters ────────────────────────────────────────────────────

/// Paints static concentric rings — repaint-free, rendered once.
class _TargetRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.42;

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 5 evenly spaced rings at 20 % intervals.
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(centre, outerRadius * i / 5, ringPaint);
    }

    // Outer boundary — slightly brighter.
    ringPaint.color = Colors.white.withOpacity(0.35);
    canvas.drawCircle(centre, outerRadius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _TargetRingsPainter _) => false;
}

/// Animated crosshair lines + pulsing centre bullseye dot.
class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter({required this.pulse});

  /// Value in [0.0, 1.0] driven by the animation controller.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.42;

    // ── Crosshair lines ───────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const gap = 18.0; // gap around centre
    // Horizontal
    canvas
      ..drawLine(
          centre.translate(-outerRadius, 0), centre.translate(-gap, 0), linePaint)
      ..drawLine(
          centre.translate(gap, 0), centre.translate(outerRadius, 0), linePaint)
      // Vertical
      ..drawLine(
          centre.translate(0, -outerRadius), centre.translate(0, -gap), linePaint)
      ..drawLine(
          centre.translate(0, gap), centre.translate(0, outerRadius), linePaint);

    // ── Pulsing centre dot ────────────────────────────────────────────────
    final dotRadius = 3.5 + pulse * 2.0;
    final dotOpacity = 0.55 + pulse * 0.45;

    final dotPaint = Paint()
      ..color = Colors.redAccent.withOpacity(dotOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(centre, dotRadius, dotPaint);

    // Dot outline ring.
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.6 * dotOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(centre, dotRadius + 3 + pulse * 2, ringPaint);

    // ── Cardinal tick marks ────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const tickLen = 6.0;
    for (var angle = 0; angle < 360; angle += 90) {
      final rad = angle * math.pi / 180;
      final from = centre + Offset(
        math.cos(rad) * (outerRadius - tickLen),
        math.sin(rad) * (outerRadius - tickLen),
      );
      final to = centre +
          Offset(math.cos(rad) * outerRadius, math.sin(rad) * outerRadius);
      canvas.drawLine(from, to, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter old) => old.pulse != pulse;
}
