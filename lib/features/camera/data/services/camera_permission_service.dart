import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/logger.dart';

/// Thin wrapper around [permission_handler] for the camera permission.
///
/// All methods are idempotent — safe to call repeatedly.
class CameraPermissionService {
  const CameraPermissionService();

  /// Returns the current permission status without prompting the user.
  Future<CameraPermissionStatus> check() async {
    final status = await Permission.camera.status;
    AppLogger.d('Camera permission status: $status');
    return _map(status);
  }

  /// Requests the permission if it has not been decided yet.
  ///
  /// Returns the resulting status.  If the permission was already granted or
  /// permanently denied this is a no-op (returns the current status).
  Future<CameraPermissionStatus> request() async {
    final current = await check();
    if (current == CameraPermissionStatus.granted) return current;
    if (current == CameraPermissionStatus.permanentlyDenied) return current;

    final result = await Permission.camera.request();
    AppLogger.i('Camera permission request result: $result');
    return _map(result);
  }

  /// Opens the OS app-settings page so the user can manually grant permission.
  Future<bool> openSettings() => openAppSettings();

  CameraPermissionStatus _map(PermissionStatus s) => switch (s) {
        PermissionStatus.granted => CameraPermissionStatus.granted,
        PermissionStatus.permanentlyDenied =>
          CameraPermissionStatus.permanentlyDenied,
        PermissionStatus.restricted => CameraPermissionStatus.permanentlyDenied,
        _ => CameraPermissionStatus.denied,
      };
}

enum CameraPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}
