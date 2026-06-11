import 'package:permission_handler/permission_handler.dart';

typedef MicrophonePermissionRequester = Future<bool> Function();

Future<bool> requestMicrophonePermission() async {
  var status = await Permission.microphone.status;
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.microphone.status;
    return status.isGranted;
  }
  status = await Permission.microphone.request();
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.microphone.status;
  }
  return status.isGranted;
}

/// Overridden in widget tests to bypass platform permission dialogs.
MicrophonePermissionRequester microphonePermissionRequester =
    requestMicrophonePermission;
