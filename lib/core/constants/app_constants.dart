/// Top-level application constants.
abstract final class AppConstants {
  AppConstants._();

  static const String appName = 'Target Analyser';
  static const String appVersion = '1.0.0';

  // Camera
  static const int imageQuality = 90;
  static const double defaultZoomLevel = 1.0;

  // Analysis
  static const int maxShotsPerSession = 30;
  static const double targetDiameterCm = 60.0; // standard ISSF 60 cm target

  // Audio
  static const double defaultVolume = 0.8;

  // UI
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
}
