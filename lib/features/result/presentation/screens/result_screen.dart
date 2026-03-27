import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:target_analyser/features/analysis/data/services/shot_analysis_service.dart';
import 'package:target_analyser/features/analysis/domain/entities/shot_pattern.dart';
import 'package:target_analyser/features/audio/presentation/providers/audio_provider.dart';
import 'package:target_analyser/features/camera/presentation/screens/camera_screen.dart';
import 'package:target_analyser/features/home/presentation/screens/home_screen.dart';
import 'package:target_analyser/features/processing/domain/entities/processed_image.dart';
import 'package:target_analyser/features/processing/presentation/providers/processing_provider.dart';

/// Unified result screen: processes the captured image, draws an overlay with
/// the detected centre and shot point, and displays the pattern + error type.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    required this.imagePath,
    required this.soldierId,
    super.key,
  });

  final String imagePath;
  final String soldierId;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  /// Native pixel dimensions of the processed image (needed by the painter).
  Size? _nativeSize;

  /// Shot analysis computed once the processed image is ready.
  ShotPattern? _pattern;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Decodes the processed image to retrieve its native dimensions.
  Future<void> _loadNativeSize(String processedPath) async {
    if (_nativeSize != null) return;
    final bytes = await File(processedPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _nativeSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
    }
  }

  /// Runs the single-shot pattern analysis synchronously.
  void _analysePattern(ProcessedImage processed) {
    if (_pattern != null) return;
    const center = (x: 0.0, y: 0.0);
    final shot = (
      x: processed.normalisedOffsetX,
      y: processed.normalisedOffsetY,
    );
    final pattern = const ShotAnalysisService().analyse(
      center: center,
      shots: [shot],
    );
    setState(() => _pattern = pattern);

    // Play coaching audio when an error is detected.
    if (pattern.error != null) {
      ref.read(audioProvider.notifier).playErrorSound(pattern.error!);
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _scanAgain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CameraScreen(soldierId: widget.soldierId),
      ),
    );
  }

  void _done() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final processedAsync = ref.watch(processingProvider(widget.imagePath));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.soldierId),
        automaticallyImplyLeading: false,
      ),
      body: processedAsync.when(
        loading: () => const _LoadingView(label: 'Processing image…'),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref
              .read(processingProvider(widget.imagePath).notifier)
              .retry(widget.imagePath),
        ),
        data: (processed) {
          // Side-effects triggered once data is available.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadNativeSize(processed.processedPath);
            _analysePattern(processed);
          });

          return _ResultView(
            processed: processed,
            nativeSize: _nativeSize,
            pattern: _pattern,
            onScanAgain: _scanAgain,
            onDone: _done,
          );
        },
      ),
    );
  }
}

// ── Result layout ─────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.processed,
    required this.nativeSize,
    required this.pattern,
    required this.onScanAgain,
    required this.onDone,
  });

  final ProcessedImage processed;
  final Size? nativeSize;
  final ShotPattern? pattern;
  final VoidCallback onScanAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Image + overlay ────────────────────────────────────────────────
        Expanded(
          child: _ImageOverlay(
            processedPath: processed.processedPath,
            nativeSize: nativeSize,
            centreX: processed.centreX,
            centreY: processed.centreY,
            shotX: processed.shotX,
            shotY: processed.shotY,
          ),
        ),

        // ── Analysis cards ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pattern != null) ...[
                _PatternCard(pattern: pattern!),
                const SizedBox(height: 8),
              ] else
                const LinearProgressIndicator(),

              const SizedBox(height: 12),

              // ── Action buttons ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onScanAgain,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDone,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Image + overlay painter ───────────────────────────────────────────────────

class _ImageOverlay extends StatelessWidget {
  const _ImageOverlay({
    required this.processedPath,
    required this.nativeSize,
    required this.centreX,
    required this.centreY,
    required this.shotX,
    required this.shotY,
  });

  final String processedPath;
  final Size? nativeSize;
  final double centreX;
  final double centreY;
  final double shotX;
  final double shotY;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Annotated image from OpenCV ────────────────────────────────────
        Image.file(
          File(processedPath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),

        // ── Custom overlay (centre crosshair + shot dot) ──────────────────
        if (nativeSize != null)
          LayoutBuilder(
            builder: (_, constraints) => CustomPaint(
              painter: _ShotOverlayPainter(
                imageSize: nativeSize!,
                centreX: centreX,
                centreY: centreY,
                shotX: shotX,
                shotY: shotY,
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws a crosshair at the detected target centre and a dot at the shot
/// position, mapped from image-pixel coordinates into widget coordinates.
class _ShotOverlayPainter extends CustomPainter {
  const _ShotOverlayPainter({
    required this.imageSize,
    required this.centreX,
    required this.centreY,
    required this.shotX,
    required this.shotY,
  });

  final Size imageSize;
  final double centreX;
  final double centreY;
  final double shotX;
  final double shotY;

  /// Maps an image-pixel coordinate to widget space, accounting for
  /// BoxFit.contain letterboxing.
  Offset _toWidget(Size widgetSize, double ix, double iy) {
    final scale = math.min(
      widgetSize.width / imageSize.width,
      widgetSize.height / imageSize.height,
    );
    final dx = (widgetSize.width - imageSize.width * scale) / 2;
    final dy = (widgetSize.height - imageSize.height * scale) / 2;
    return Offset(ix * scale + dx, iy * scale + dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerPt = _toWidget(size, centreX, centreY);
    final shotPt = _toWidget(size, shotX, shotY);

    _drawCrosshair(canvas, centerPt);
    _drawShotMarker(canvas, shotPt);
  }

  void _drawCrosshair(Canvas canvas, Offset c) {
    const r = 11.0;
    const arm = 9.0;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Ring
    canvas.drawCircle(c, r, paint);

    // Four arms extending outward from the ring
    canvas.drawLine(Offset(c.dx - r - arm, c.dy), Offset(c.dx - r, c.dy), paint);
    canvas.drawLine(Offset(c.dx + r, c.dy), Offset(c.dx + r + arm, c.dy), paint);
    canvas.drawLine(Offset(c.dx, c.dy - r - arm), Offset(c.dx, c.dy - r), paint);
    canvas.drawLine(Offset(c.dx, c.dy + r), Offset(c.dx, c.dy + r + arm), paint);
  }

  void _drawShotMarker(Canvas canvas, Offset p) {
    // White outer ring
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Red fill
    canvas.drawCircle(
      p,
      6,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ShotOverlayPainter old) =>
      old.centreX != centreX ||
      old.centreY != centreY ||
      old.shotX != shotX ||
      old.shotY != shotY ||
      old.imageSize != imageSize;
}

// ── Pattern + error card ──────────────────────────────────────────────────────

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});
  final ShotPattern pattern;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shot = pattern.shots.firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Error badge (left) ────────────────────────────────────────
            _ErrorBadge(error: pattern.error),
            const SizedBox(width: 16),

            // ── Shot metrics (centre) ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _patternLabel(pattern.pattern),
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (shot != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Distance ${shot.distance.toStringAsFixed(1)} px'
                      '  •  ${shot.clockHour}:00',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                  if (pattern.error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _errorDescription(pattern.error!),
                      style: tt.bodySmall,
                    ),
                  ],
                ],
              ),
            ),

            // ── Clock hour chip (right) ───────────────────────────────────
            if (shot != null)
              _ClockChip(hour: shot.clockHour),
          ],
        ),
      ),
    );
  }

  String _patternLabel(PatternType t) => switch (t) {
        PatternType.horizontal => 'Horizontal',
        PatternType.vertical   => 'Vertical',
        PatternType.bifocal    => 'Bifocal',
        PatternType.scattered  => 'Scattered',
      };

  String _errorDescription(ShooterError e) => switch (e) {
        ShooterError.jerk   => 'Trigger finger pulling inward',
        ShooterError.buck   => 'Anticipating recoil (heeling)',
        ShooterError.flinch => 'Involuntary flinch before break',
      };
}

class _ErrorBadge extends StatelessWidget {
  const _ErrorBadge({required this.error});
  final ShooterError? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.shade100,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check, color: Colors.green.shade700, size: 24),
      );
    }

    final (color, icon, label) = switch (error!) {
      ShooterError.jerk   => (Colors.orange, Icons.rotate_right, 'JERK'),
      ShooterError.buck   => (Colors.red, Icons.arrow_downward, 'BUCK'),
      ShooterError.flinch => (Colors.deepPurple, Icons.bolt, 'FLINCH'),
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.hour});
  final int hour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$hour:00',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ── Loading / Error states ────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ],
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
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
