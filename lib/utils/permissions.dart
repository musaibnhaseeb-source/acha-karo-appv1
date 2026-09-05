// lib/utils/permissions.dart
import 'package:permission_handler/permission_handler.dart';

/// Permission management helper for MVP
class PermissionManager {
  /// Request camera permission for photo submissions
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request location permission for GPS deed logging
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request storage permission for photo gallery access
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request all permissions needed for deed submission flow
  /// Returns true only if BOTH camera and location are granted
  static Future<bool> requestAllDeedSubmissionPermissions() async {
    final results = await Future.wait([
      Permission.camera.request(),
      Permission.location.request(),
    ]);
    return results.every((status) => status.isGranted);
  }

  /// Check current camera permission status without requesting
  static Future<PermissionStatus> checkCameraStatus() => Permission.camera.status;

  /// Check current location permission status without requesting
  static Future<PermissionStatus> checkLocationStatus() => Permission.location.status;

  /// Check current storage permission status without requesting
  static Future<PermissionStatus> checkStorageStatus() => Permission.storage.status;

  /// Returns true if permission is permanently denied (user chose "Don't ask again")
  static Future<bool> isCameraPermissionPermanentlyDenied() async {
    final status = await Permission.camera.status;
    return status.isDenied && await Permission.camera.isDenied;
  }

  /// Returns true if permission is permanently denied (user chose "Don't ask again")
  static Future<bool> isLocationPermissionPermanentlyDenied() async {
    final status = await Permission.location.status;
    return status.isDenied && await Permission.location.isDenied;
  }

  /// Open app settings if permissions are permanently denied
  static Future<void> openAppSettings() => openAppSettings();
}
