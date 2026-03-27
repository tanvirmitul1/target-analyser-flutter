import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logger.dart';

// ── Public result type ────────────────────────────────────────────────────────

class CompressResult {
  const CompressResult({
    required this.outputPath,
    required this.originalWidth,
    required this.originalHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.elapsedMs,
  });

  final String outputPath;
  final int originalWidth;
  final int originalHeight;
  final int outputWidth;
  final int outputHeight;
  final int elapsedMs;

  bool get wasResized =>
      originalWidth != outputWidth || originalHeight != outputHeight;

  String get originalSize => '${originalWidth}×${originalHeight}';
  String get outputSize   => '${outputWidth}×${outputHeight}';

  @override
  String toString() =>
      'CompressResult($originalSize→$outputSize ${elapsedMs}ms)';
}

// ── Compressor ────────────────────────────────────────────────────────────────

/// Resizes and re-encodes a JPEG in a background isolate so the main thread
/// (and the OpenCV worker thread) never block on full-resolution I/O.
///
/// Strategy:
///  - If neither dimension exceeds [_kMaxDimension], only re-encode at
///    [_kQuality] (removes EXIF bloat, reduces file size).
///  - If larger, use Lanczos-3 downscale preserving aspect ratio.
///
/// The returned [CompressResult.outputPath] is in the OS temp directory and
/// is the caller's responsibility to delete after use.
abstract final class ImageCompressor {
  static const int _kMaxDimension = 1200;
  static const int _kQuality      = 82;

  static Future<CompressResult> compress(String inputPath) async {
    final tmpDir = await getTemporaryDirectory();
    final outName =
        'cmp_${p.basenameWithoutExtension(inputPath)}_'
        '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputPath = p.join(tmpDir.path, outName);

    AppLogger.d('ImageCompressor: compressing "$inputPath" → "$outputPath"');

    final result = await compute(
      _compressInIsolate,
      _CompressArgs(
        inputPath: inputPath,
        outputPath: outputPath,
        maxDimension: _kMaxDimension,
        quality: _kQuality,
      ),
    );

    AppLogger.i('ImageCompressor: $result');
    return result;
  }
}

// ── Isolate boundary types ────────────────────────────────────────────────────

/// All fields must be primitive — this crosses the isolate boundary.
final class _CompressArgs {
  const _CompressArgs({
    required this.inputPath,
    required this.outputPath,
    required this.maxDimension,
    required this.quality,
  });
  final String inputPath;
  final String outputPath;
  final int    maxDimension;
  final int    quality;
}

// ── Top-level isolate function ────────────────────────────────────────────────

/// Must be a top-level function so [compute] can send it across the isolate
/// port.  All I/O and CPU work happens here — the main isolate is free.
Future<CompressResult> _compressInIsolate(_CompressArgs args) async {
  final sw = Stopwatch()..start();

  final bytes = await File(args.inputPath).readAsBytes();
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw StateError('ImageCompressor: failed to decode "${args.inputPath}"');
  }

  final origW = image.width;
  final origH = image.height;

  // Resize if either dimension exceeds the limit.
  if (origW > args.maxDimension || origH > args.maxDimension) {
    image = origW >= origH
        ? img.copyResize(
            image,
            width: args.maxDimension,
            interpolation: img.Interpolation.linear,
          )
        : img.copyResize(
            image,
            height: args.maxDimension,
            interpolation: img.Interpolation.linear,
          );
  }

  final encoded = img.encodeJpg(image, quality: args.quality);
  await File(args.outputPath).writeAsBytes(encoded, flush: true);

  return CompressResult(
    outputPath:    args.outputPath,
    originalWidth: origW,
    originalHeight: origH,
    outputWidth:   image.width,
    outputHeight:  image.height,
    elapsedMs:     sw.elapsedMilliseconds,
  );
}
