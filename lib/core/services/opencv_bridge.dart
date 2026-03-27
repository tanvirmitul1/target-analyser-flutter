import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/opencv_result.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Flutter-side singleton that owns the [MethodChannel] to
/// the native `image_processor` channel registered in [MainActivity.kt].
///
/// Usage:
/// ```dart
/// final result = await OpenCvBridge.instance.processImage(path);
/// result.when(
///   onSuccess: (r) => ...,
///   onFailure: (f) => ...,
/// );
/// ```
class OpenCvBridge {
  const OpenCvBridge._();

  static const OpenCvBridge instance = OpenCvBridge._();

  // Must match [CHANNEL] constant in MainActivity.kt.
  static const MethodChannel _channel = MethodChannel('image_processor');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Sends [imagePath] to the native layer for OpenCV processing.
  ///
  /// Returns [Success<OpenCvResult>] on success or a typed [ProcessingFailure]
  /// on any error — PlatformException codes are preserved in the failure
  /// message for diagnostics.
  Future<Result<OpenCvResult>> processImage(String imagePath) async {
    AppLogger.d('OpenCvBridge → processImage("$imagePath")');

    try {
      final raw = await _channel.invokeMethod<String>(
        'processImage',
        {'path': imagePath},
      );

      if (raw == null || raw.isEmpty) {
        return const Failure(
          ProcessingFailure('OpenCV channel returned an empty response.'),
        );
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final result = OpenCvResult.fromJson(json);

      AppLogger.i(
        'OpenCvBridge ← centre=${result.center} '
        'shots=${result.shots.length} '
        'debug=${result.debug}',
      );

      return Success(result);
    } on PlatformException catch (e, st) {
      final code = e.code;
      final msg  = e.message ?? 'Platform error';
      AppLogger.e('OpenCvBridge PlatformException [$code]: $msg',
          error: e, stackTrace: st);
      return Failure(
        ProcessingFailure('[$code] $msg', cause: e),
      );
    } on FormatException catch (e, st) {
      AppLogger.e('OpenCvBridge JSON parse error', error: e, stackTrace: st);
      return Failure(
        ProcessingFailure('Could not parse OpenCV response JSON.', cause: e),
      );
    } catch (e, st) {
      AppLogger.e('OpenCvBridge unexpected error', error: e, stackTrace: st);
      return Failure(
        ProcessingFailure('Unexpected error during OpenCV processing.', cause: e),
      );
    }
  }
}
