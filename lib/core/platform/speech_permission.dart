import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

typedef SpeechPermissionRequester = Future<bool> Function();

Future<bool> requestSpeechPermission() async {
  // iOS requires explicit Speech Recognition permission (separate from mic).
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return true;
  }

  var status = await Permission.speech.status;
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.speech.status;
    return status.isGranted;
  }
  status = await Permission.speech.request();
  if (status.isGranted) {
    return true;
  }
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    status = await Permission.speech.status;
  }
  return status.isGranted;
}

/// Overridden in widget tests to bypass platform permission dialogs.
SpeechPermissionRequester speechPermissionRequester = requestSpeechPermission;
