import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/logger.dart';
import '../models/processed_image_model.dart';

/// Image processing logic using the `image` package.
///
/// Current implementation uses a simplified heuristic approach:
/// - Target centre is assumed to be the geometric centre of the image.
/// - Target radius is estimated as 40% of the shorter image dimension.
/// - Shot detection finds the darkest region cluster.
///
/// Replace these heuristics with ML-based or OpenCV approaches for production.
class ImageProcessingDatasource {
  Future<ProcessedImageModel> processImage(String imagePath) async {
    AppLogger.i('Processing image: $imagePath');

    final bytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw StateError('Could not decode image at $imagePath');

    final w = image.width;
    final h = image.height;
    final centreX = w / 2.0;
    final centreY = h / 2.0;
    final radius = math.min(w, h) * 0.40;

    // --- Shot detection (darkest pixel cluster) ---
    final shotPoint = _findShotCentre(image, centreX, centreY, radius);

    // --- Annotate image ---
    _drawCircle(image, centreX.round(), centreY.round(), radius.round(),
        img.ColorRgb8(255, 0, 0));
    _drawCrosshair(image, shotPoint.$1, shotPoint.$2, img.ColorRgb8(0, 255, 0));

    // --- Save processed image ---
    final outputPath = await _saveProcessed(imagePath, image);

    AppLogger.i('Processing complete → $outputPath');

    return ProcessedImageModel(
      originalPath: imagePath,
      processedPath: outputPath,
      centreX: centreX,
      centreY: centreY,
      targetRadiusPx: radius,
      shotX: shotPoint.$1.toDouble(),
      shotY: shotPoint.$2.toDouble(),
      processedAt: DateTime.now().toIso8601String(),
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  (int, int) _findShotCentre(
    img.Image image,
    double centreX,
    double centreY,
    double radius,
  ) {
    var minLuma = 255;
    var bestX = centreX.round();
    var bestY = centreY.round();

    // Sample pixels within the target circle.
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final dx = x - centreX;
        final dy = y - centreY;
        if (dx * dx + dy * dy > radius * radius) continue;

        final pixel = image.getPixel(x, y);
        final luma =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
        if (luma < minLuma) {
          minLuma = luma;
          bestX = x;
          bestY = y;
        }
      }
    }
    return (bestX, bestY);
  }

  void _drawCircle(img.Image image, int cx, int cy, int r, img.Color color) {
    for (var angle = 0.0; angle < math.pi * 2; angle += 0.005) {
      final x = (cx + r * math.cos(angle)).round().clamp(0, image.width - 1);
      final y = (cy + r * math.sin(angle)).round().clamp(0, image.height - 1);
      image.setPixel(x, y, color);
    }
  }

  void _drawCrosshair(img.Image image, int cx, int cy, img.Color color) {
    const size = 20;
    for (var i = -size; i <= size; i++) {
      final x = (cx + i).clamp(0, image.width - 1);
      final y = (cy + i).clamp(0, image.height - 1);
      image.setPixel(x, cy, color);
      image.setPixel(cx, y, color);
    }
  }

  Future<String> _saveProcessed(String originalPath, img.Image image) async {
    final dir = await getApplicationDocumentsDirectory();
    final processedDir = Directory(p.join(dir.path, 'processed'));
    await processedDir.create(recursive: true);

    final fileName =
        'proc_${p.basenameWithoutExtension(originalPath)}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputPath = p.join(processedDir.path, fileName);
    await File(outputPath).writeAsBytes(img.encodeJpg(image, quality: 90));
    return outputPath;
  }
}
