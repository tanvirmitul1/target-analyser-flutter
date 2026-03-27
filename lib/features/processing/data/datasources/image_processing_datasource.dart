import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/logger.dart';
import '../models/processed_image_model.dart';
import 'base_processing_datasource.dart';

/// Pure-Dart fallback image processor using the `image` package.
///
/// Used when the OpenCV platform channel is unavailable (iOS, unit tests, or
/// when OpenCV initialisation fails on-device).
///
/// ## Algorithm
/// - Target centre  = geometric centre of the image.
/// - Target radius  = 40 % of the shorter edge.
/// - Shot location  = darkest-pixel cluster inside the target circle.
///
/// ## Performance
/// The full pixel scan is dispatched to a background isolate via [compute] so
/// the Flutter UI thread and the platform thread are never blocked.
/// [const ImageProcessingDatasource()] remains a zero-state singleton.
class ImageProcessingDatasource implements BaseProcessingDatasource {
  const ImageProcessingDatasource();

  @override
  Future<ProcessedImageModel> processImage(String imagePath) async {
    AppLogger.i('ImageProcessingDatasource: processing "$imagePath" (Dart fallback)');
    final sw = Stopwatch()..start();

    // Output path is resolved on the main isolate (needs plugin context).
    final outputPath = await _resolveOutputPath(imagePath);

    final result = await compute(
      _processInIsolate,
      _IsolateArgs(imagePath: imagePath, outputPath: outputPath),
    );

    AppLogger.i(
      'ImageProcessingDatasource: done in ${sw.elapsedMilliseconds} ms '
      'shot=(${result.shotX.toStringAsFixed(1)}, ${result.shotY.toStringAsFixed(1)})',
    );

    return ProcessedImageModel(
      originalPath:   imagePath,
      processedPath:  outputPath,
      centreX:        result.centreX,
      centreY:        result.centreY,
      targetRadiusPx: result.radius,
      shotX:          result.shotX,
      shotY:          result.shotY,
      processedAt:    DateTime.now().toUtc().toIso8601String(),
      usedFallback:   true,
    );
  }

  static Future<String> _resolveOutputPath(String imagePath) async {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'processed'),
    );
    await dir.create(recursive: true);
    final name =
        'proc_${p.basenameWithoutExtension(imagePath)}'
        '_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return p.join(dir.path, name);
  }
}

// ── Isolate boundary types ────────────────────────────────────────────────────

final class _IsolateArgs {
  const _IsolateArgs({required this.imagePath, required this.outputPath});
  final String imagePath;
  final String outputPath;
}

final class _IsolateResult {
  const _IsolateResult({
    required this.centreX,
    required this.centreY,
    required this.radius,
    required this.shotX,
    required this.shotY,
  });
  final double centreX;
  final double centreY;
  final double radius;
  final double shotX;
  final double shotY;
}

// ── Top-level isolate function ────────────────────────────────────────────────

/// All image work runs here — never on the main or platform thread.
Future<_IsolateResult> _processInIsolate(_IsolateArgs args) async {
  final bytes = await File(args.imagePath).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw StateError(
        'ImageProcessingDatasource: cannot decode "${args.imagePath}"');
  }

  final w       = image.width.toDouble();
  final h       = image.height.toDouble();
  final centreX = w / 2.0;
  final centreY = h / 2.0;
  final radius  = math.min(w, h) * 0.40;

  final (shotX, shotY) = _findShotCentre(image, centreX, centreY, radius);

  _annotate(image, centreX, centreY, radius, shotX, shotY);

  final encoded = img.encodeJpg(image, quality: 85);
  await File(args.outputPath).writeAsBytes(encoded, flush: true);

  return _IsolateResult(
    centreX: centreX,
    centreY: centreY,
    radius:  radius,
    shotX:   shotX.toDouble(),
    shotY:   shotY.toDouble(),
  );
}

// ── Image analysis helpers (run inside the isolate) ──────────────────────────

/// Scans pixels inside the target circle and returns the centre of the
/// darkest cluster (the bullet hole).
(int, int) _findShotCentre(
  img.Image image,
  double centreX,
  double centreY,
  double radius,
) {
  var minLuma = 256;
  var bestX   = centreX.round();
  var bestY   = centreY.round();

  final r2 = radius * radius;
  final x0 = (centreX - radius).floor().clamp(0, image.width  - 1);
  final x1 = (centreX + radius).ceil().clamp(0, image.width   - 1);
  final y0 = (centreY - radius).floor().clamp(0, image.height - 1);
  final y1 = (centreY + radius).ceil().clamp(0, image.height  - 1);

  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = x - centreX;
      final dy = y - centreY;
      if (dx * dx + dy * dy > r2) continue;

      final px    = image.getPixel(x, y);
      final luma  = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b).round();
      if (luma < minLuma) {
        minLuma = luma;
        bestX   = x;
        bestY   = y;
      }
    }
  }
  return (bestX, bestY);
}

/// Draws target circle + shot crosshair onto [image] in-place.
void _annotate(
  img.Image image,
  double cx,
  double cy,
  double radius,
  int shotX,
  int shotY,
) {
  final red   = img.ColorRgb8(220, 40,  40);
  final green = img.ColorRgb8(40,  220, 40);

  // Target boundary circle.
  final r   = radius.round();
  final icx = cx.round();
  final icy = cy.round();
  for (var angle = 0.0; angle < math.pi * 2; angle += 0.003) {
    final px = (icx + r * math.cos(angle)).round().clamp(0, image.width  - 1);
    final py = (icy + r * math.sin(angle)).round().clamp(0, image.height - 1);
    image.setPixel(px, py, red);
  }

  // Shot crosshair.
  const arm = 20;
  for (var i = -arm; i <= arm; i++) {
    image.setPixel((shotX + i).clamp(0, image.width  - 1), shotY, green);
    image.setPixel(shotX, (shotY + i).clamp(0, image.height - 1), green);
  }
}
