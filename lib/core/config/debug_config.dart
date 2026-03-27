import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global debug-mode toggle.
///
/// When true:
///  - The OpenCV native layer draws additional overlays (all raw contours
///    before the area filter, intermediate adaptive-threshold mask).
///  - [ResultScreen] shows a debug info panel with step timings, detection
///    counts, image dimensions, and whether the Dart fallback was used.
///
/// Toggle at runtime via:
/// ```dart
/// ref.read(debugModeProvider.notifier).state = true;
/// ```
final debugModeProvider = StateProvider<bool>((ref) => false);
