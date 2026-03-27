import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/shot_result.dart';

/// Paints all shots in a session on a target diagram.
class ShotScatterChart extends StatelessWidget {
  const ShotScatterChart({required this.shots, super.key});
  final List<ShotResult> shots;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _TargetPainter(
          shots: shots,
          ringColor: Theme.of(context).colorScheme.outline,
          shotColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  _TargetPainter({
    required this.shots,
    required this.ringColor,
    required this.shotColor,
  });

  final List<ShotResult> shots;
  final Color ringColor;
  final Color shotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 4;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fillPaint = Paint()
      ..color = ringColor.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Draw rings 1-10.
    for (var ring = 1; ring <= 10; ring++) {
      final r = maxRadius * (ring / 10);
      canvas.drawCircle(centre, r, fillPaint);
      canvas.drawCircle(centre, r, ringPaint);
    }

    // Draw crosshair.
    final crossPaint = Paint()
      ..color = ringColor.withOpacity(0.3)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      centre.translate(-maxRadius, 0),
      centre.translate(maxRadius, 0),
      crossPaint,
    );
    canvas.drawLine(
      centre.translate(0, -maxRadius),
      centre.translate(0, maxRadius),
      crossPaint,
    );

    // Draw shots.
    final shotPaint = Paint()
      ..color = shotColor
      ..style = PaintingStyle.fill;

    for (final shot in shots) {
      if (shot.isMiss) continue;
      final x = centre.dx + shot.offsetX * maxRadius;
      final y = centre.dy + shot.offsetY * maxRadius;
      canvas.drawCircle(Offset(x, y), 5, shotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TargetPainter oldDelegate) =>
      oldDelegate.shots != shots;
}
