import 'package:permission_handler/permission_handler.dart';

typedef CameraPermissionRequester = Future<bool> Function();

Future<bool> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.camera.status;
    return status.isGranted;
  }
  status = await Permission.camera.request();
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.camera.status;
  }
  return status.isGranted;
}

/// Overridden in widget tests to bypass platform permission dialogs.
CameraPermissionRequester cameraPermissionRequester = requestCameraPermission;
