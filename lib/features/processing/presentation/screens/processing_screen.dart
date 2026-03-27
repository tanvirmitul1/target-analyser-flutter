import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/async_value_widget.dart';
import '../../../../core/utils/extensions.dart';
import '../../../analysis/presentation/screens/analysis_screen.dart';
import '../../domain/entities/processed_image.dart';
import '../providers/processing_provider.dart';

class ProcessingScreen extends ConsumerWidget {
  const ProcessingScreen({
    required this.imagePath,
    required this.sessionId,
    super.key,
  });

  final String imagePath;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processedAsync = ref.watch(processingProvider(imagePath));

    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: AsyncValueWidget(
        value: processedAsync,
        loading: const _ProcessingIndicator(),
        data: (processed) => Column(
          children: [
            Expanded(
              child: _AnnotatedImageView(processed: processed),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${processed.allShots.length} shot(s) detected'
                    '${processed.usedFallback ? ' (fallback)' : ''}',
                    style: context.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => AnalysisScreen(
                          sessionId: sessionId,
                          processedImage: processed,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Analyse Shot'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(processingProvider(imagePath).notifier)
                            .retry(imagePath),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(processingProvider(imagePath).notifier)
                        .retry(imagePath),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Annotated image + Flutter overlay ────────────────────────────────────────

/// Shows the Kotlin-annotated JPEG inside an [InteractiveViewer] and draws a
/// Flutter [CustomPaint] overlay for all shot centres and the target centre.
///
/// The overlay uses the same coordinate space as the image pixels, scaled to
/// match the display size via [BoxFit.contain] logic.
class _AnnotatedImageView extends StatelessWidget {
  const _AnnotatedImageView({required this.processed});

  final ProcessedImage processed;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 8.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dispW = constraints.maxWidth;
          final dispH = constraints.maxHeight;

          // Compute BoxFit.contain scale + offset so the overlay matches the
          // displayed image exactly.
          final imgW = processed.imageWidthPx.toDouble();
          final imgH = processed.imageHeightPx.toDouble();

          // Guard: if dimensions are unknown (e.g. fallback wrote 0×0), just
          // show the image without the Flutter overlay.
          if (imgW == 0 || imgH == 0) {
            return Image.file(File(processed.processedPath), fit: BoxFit.contain);
          }

          final scaleX  = dispW / imgW;
          final scaleY  = dispH / imgH;
          final scale   = math.min(scaleX, scaleY);
          final offsetX = (dispW - imgW * scale) / 2;
          final offsetY = (dispH - imgH * scale) / 2;

          return Stack(
            children: [
              // Annotated image already drawn by OpenCV in Kotlin.
              Positioned.fill(
                child: Image.file(
                  File(processed.processedPath),
                  fit: BoxFit.contain,
                ),
              ),
              // Flutter overlay — zooms and pans with the image.
              Positioned.fill(
                child: CustomPaint(
                  painter: ShotOverlayPainter(
                    processed: processed,
                    scale:     scale,
                    offsetX:   offsetX,
                    offsetY:   offsetY,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── ShotOverlayPainter ────────────────────────────────────────────────────────

/// Draws:
///  • A cyan circle at the detected target centre.
///  • A red ring + numbered label for each detected shot hole.
///
/// All coordinates are in image-pixel space; [scale] and [offset*] map them
/// to the widget's display space (computed from [BoxFit.contain] geometry).
class ShotOverlayPainter extends CustomPainter {
  const ShotOverlayPainter({
    required this.processed,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  final ProcessedImage processed;
  final double scale;
  final double offsetX;
  final double offsetY;

  /// Converts image-pixel coordinates to display-space [Offset].
  Offset _toDisplay(double x, double y) => Offset(
        offsetX + x * scale,
        offsetY + y * scale,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // ── Target centre ────────────────────────────────────────────────────────
    final centrePos    = _toDisplay(processed.centreX, processed.centreY);
    final displayRadius = processed.targetRadiusPx * scale;

    final centrePaint = Paint()
      ..color       = const Color(0xFF00E5FF)  // cyan
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    // Outer boundary ring (thin, matches Kotlin green ring position)
    canvas.drawCircle(centrePos, displayRadius, centrePaint);

    // Crosshair at centre
    final arm = (displayRadius * 0.08).clamp(6.0, 24.0);
    canvas.drawLine(
        Offset(centrePos.dx - arm, centrePos.dy),
        Offset(centrePos.dx + arm, centrePos.dy),
        centrePaint);
    canvas.drawLine(
        Offset(centrePos.dx, centrePos.dy - arm),
        Offset(centrePos.dx, centrePos.dy + arm),
        centrePaint);

    // ── Shot holes ────────────────────────────────────────────────────────────
    final ringPaint = Paint()
      ..color       = const Color(0xFFFF1744)  // red
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final dotPaint = Paint()
      ..color = const Color(0xFF76FF03)  // lime
      ..style = PaintingStyle.fill;

    const textStyle = TextStyle(
      color:      Color(0xFF00E5FF),
      fontSize:   12,
      fontWeight: FontWeight.bold,
    );

    for (var i = 0; i < processed.allShots.length; i++) {
      final shot    = processed.allShots[i];
      final shotPos = _toDisplay(shot.x, shot.y);
      final ringR   = (18.0 * scale).clamp(6.0, 24.0);
      final dotR    = (5.0  * scale).clamp(3.0,  8.0);

      // Red ring
      canvas.drawCircle(shotPos, ringR, ringPaint);
      // Lime fill dot
      canvas.drawCircle(shotPos, dotR, dotPaint);

      // Number label
      final tp = TextPainter(
        text:            TextSpan(text: '${i + 1}', style: textStyle),
        textDirection:   TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(shotPos.dx + ringR + 4, shotPos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(ShotOverlayPainter old) =>
      old.processed != processed ||
      old.scale     != scale     ||
      old.offsetX   != offsetX   ||
      old.offsetY   != offsetY;
}

// ── Loading indicator ─────────────────────────────────────────────────────────

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Analysing target image…',
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
