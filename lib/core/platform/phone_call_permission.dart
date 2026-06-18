import 'package:permission_handler/permission_handler.dart';

typedef PhoneCallPermissionRequester = Future<bool> Function();

Future<bool> requestPhoneCallPermission() async {
  var status = await Permission.phone.status;
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.phone.status;
    return status.isGranted;
  }
  status = await Permission.phone.request();
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.phone.status;
  }
  return status.isGranted;
}

/// Overridden in widget tests to bypass platform permission dialogs.
PhoneCallPermissionRequester phoneCallPermissionRequester =
    requestPhoneCallPermission;
