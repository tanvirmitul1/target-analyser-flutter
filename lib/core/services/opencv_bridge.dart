import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/opencv_result.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Flutter-side singleton that owns the [MethodChannel] to the native
/// `image_processor` channel registered in [MainActivity.kt].
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

  // Must match [CHANNEL] in MainActivity.kt.
  static const MethodChannel _channel = MethodChannel('image_processor');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Sends [imagePath] to the native OpenCV layer for processing.
  ///
  /// [debugMode] forwards the flag to the Kotlin [ImageProcessor]; when true
  /// extra annotations are drawn and additional diagnostics are logged.
  ///
  /// Returns [Success<OpenCvResult>] on success or a typed [ProcessingFailure].
  Future<Result<OpenCvResult>> processImage(
    String imagePath, {
    bool debugMode = false,
  }) async {
    AppLogger.d('OpenCvBridge → processImage("$imagePath" debug=$debugMode)');

    try {
      final raw = await _channel.invokeMethod<String>(
        'processImage',
        {'path': imagePath, 'debugMode': debugMode},
      );

      if (raw == null || raw.isEmpty) {
        return const Failure(
          ProcessingFailure('OpenCV channel returned an empty response.'),
        );
      }

      final json   = jsonDecode(raw) as Map<String, dynamic>;
      final result = OpenCvResult.fromJson(json);

      AppLogger.i(
        'OpenCvBridge ← centre=${result.center} '
        'shots=${result.shots.length} '
        'meta=${result.meta} '
        'debug=${result.debug}',
      );

      return Success(result);
    } on PlatformException catch (e, st) {
      final code = e.code;
      final msg  = e.message ?? 'Platform error';
      AppLogger.e('OpenCvBridge PlatformException [$code]: $msg',
          error: e, stackTrace: st);
      return Failure(ProcessingFailure('[$code] $msg', cause: e));
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
