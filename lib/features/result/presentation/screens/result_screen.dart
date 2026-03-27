import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:target_analyser/features/analysis/domain/entities/shot_pattern.dart';
import 'package:target_analyser/features/camera/presentation/screens/camera_screen.dart';
import 'package:target_analyser/features/home/presentation/screens/home_screen.dart';
import 'package:target_analyser/features/processing/domain/entities/processed_image.dart';

import '../providers/scan_flow_provider.dart';

/// End-to-end result screen.
///
/// Drives the full scan pipeline (process → analyse → save → audio) via
/// [ScanFlowNotifier] and renders the appropriate UI for each step.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({
    required this.imagePath,
    required this.soldierId,
    super.key,
  });

  final String imagePath;
  final String soldierId;

  ScanArgs get _args => (imagePath: imagePath, soldierId: soldierId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show save-failure warning as a snackbar without blocking the result UI.
    ref.listen<ScanFlowState>(scanFlowProvider(_args), (_, next) {
      if (next is ScanComplete && next.saveWarning != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not save: ${next.saveWarning}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    final state = ref.watch(scanFlowProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          soldierId,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: switch (state) {
        ScanProcessing() => const _StepView(
            step: 1,
            label: 'Processing image…',
          ),
        ScanAnalysing()  => const _StepView(
            step: 2,
            label: 'Analysing shot…',
          ),
        ScanSaving()     => const _StepView(
            step: 3,
            label: 'Saving…',
          ),
        ScanComplete complete => _CompleteView(
            state: complete,
            onScanAgain: () => _scanAgain(context),
            onDone: () => _done(context),
          ),
        ScanFailed failed => _FailedView(
            failed: failed,
            onRetry: () =>
                ref.read(scanFlowProvider(_args).notifier).retry(),
          ),
      },
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _scanAgain(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CameraScreen(soldierId: soldierId),
      ),
    );
  }

  void _done(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }
}

// ── Step loading view ─────────────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  const _StepView({required this.step, required this.label});

  /// Current pipeline step (1 = processing, 2 = analysing, 3 = saving).
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 28),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            _StepIndicator(current: step),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const labels = ['Process', 'Analyse', 'Save'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0)
            SizedBox(
              width: 32,
              child: Divider(
                color: i < current ? cs.primary : cs.outlineVariant,
                thickness: 1.5,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i + 1 <= current ? cs.primary : cs.surfaceContainerHighest,
                ),
                alignment: Alignment.center,
                child: i + 1 < current
                    ? Icon(Icons.check, size: 14, color: cs.onPrimary)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: i + 1 == current
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: i + 1 <= current ? cs.primary : cs.outline,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Complete (result) view ────────────────────────────────────────────────────

class _CompleteView extends StatelessWidget {
  const _CompleteView({
    required this.state,
    required this.onScanAgain,
    required this.onDone,
  });

  final ScanComplete state;
  final VoidCallback onScanAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Image with overlay ─────────────────────────────────────────────
        Expanded(
          child: _ImageOverlay(
            processed: state.processed,
            nativeSize: state.nativeImageSize,
          ),
        ),

        // ── Analysis card + buttons ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PatternCard(pattern: state.pattern),
              const SizedBox(height: 12),
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

// ── Image + overlay ───────────────────────────────────────────────────────────

class _ImageOverlay extends StatelessWidget {
  const _ImageOverlay({
    required this.processed,
    required this.nativeSize,
  });

  final ProcessedImage processed;
  final Size nativeSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Annotated image produced by the native OpenCV processor.
        Image.file(
          File(processed.processedPath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),

        // Clean overlay: centre crosshair + shot marker.
        CustomPaint(
          painter: _ShotOverlayPainter(
            imageSize: nativeSize,
            centreX: processed.centreX,
            centreY: processed.centreY,
            shotX: processed.shotX,
            shotY: processed.shotY,
          ),
        ),
      ],
    );
  }
}

/// Maps image-pixel coordinates to widget coordinates (BoxFit.contain), then
/// draws a crosshair at the target centre and a dot at the shot position.
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

  Offset _map(Size widget, double ix, double iy) {
    final scale = math.min(
      widget.width / imageSize.width,
      widget.height / imageSize.height,
    );
    final ox = (widget.width - imageSize.width * scale) / 2;
    final oy = (widget.height - imageSize.height * scale) / 2;
    return Offset(ix * scale + ox, iy * scale + oy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawCrosshair(canvas, _map(size, centreX, centreY));
    _drawShot(canvas, _map(size, shotX, shotY));
  }

  void _drawCrosshair(Canvas canvas, Offset c) {
    const r = 11.0;
    const arm = 9.0;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(c, r, p);
    canvas.drawLine(Offset(c.dx - r - arm, c.dy), Offset(c.dx - r, c.dy), p);
    canvas.drawLine(Offset(c.dx + r, c.dy), Offset(c.dx + r + arm, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - r - arm), Offset(c.dx, c.dy - r), p);
    canvas.drawLine(Offset(c.dx, c.dy + r), Offset(c.dx, c.dy + r + arm), p);
  }

  void _drawShot(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 9,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(p, 6,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_ShotOverlayPainter old) =>
      old.centreX != centreX ||
      old.centreY != centreY ||
      old.shotX != shotX ||
      old.shotY != shotY ||
      old.imageSize != imageSize;
}

// ── Pattern card ──────────────────────────────────────────────────────────────

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
            _ErrorBadge(error: pattern.error),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _patternLabel(pattern.pattern),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (shot != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Distance ${shot.distance.toStringAsFixed(1)}'
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
            if (shot != null) _ClockChip(hour: shot.clockHour),
          ],
        ),
      ),
    );
  }

  static String _patternLabel(PatternType t) => switch (t) {
        PatternType.horizontal => 'Horizontal',
        PatternType.vertical   => 'Vertical',
        PatternType.bifocal    => 'Bifocal',
        PatternType.scattered  => 'Scattered',
      };

  static String _errorDescription(ShooterError e) => switch (e) {
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
      return _badge(Colors.green, Icons.check);
    }
    final (color, icon) = switch (error!) {
      ShooterError.jerk   => (Colors.orange, Icons.rotate_right),
      ShooterError.buck   => (Colors.red, Icons.arrow_downward),
      ShooterError.flinch => (Colors.deepPurple, Icons.bolt),
    };
    return _badge(color, icon);
  }

  Widget _badge(Color color, IconData icon) => Container(
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

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.hour});
  final int hour;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$hour:00',
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Failed view ───────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failed, required this.onRetry});

  final ScanFailed failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final stepLabel = switch (failed.step) {
      'processing' => 'Image processing failed',
      'analysing'  => 'Shot analysis failed',
      'saving'     => 'Could not save result',
      _            => 'An error occurred',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: cs.error),
            const SizedBox(height: 20),
            Text(
              stepLabel,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              failed.message,
              style: tt.bodySmall?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
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
