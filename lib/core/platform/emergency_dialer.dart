import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'phone_call_permission.dart';

/// Places an emergency call or opens the dialer as fallback.
typedef EmergencyDialer = Future<bool> Function(String phoneNumber);

const _emergencyCallChannel = MethodChannel(
  'com.adesso.signbridge/emergency_call',
);

Future<bool> launchEmergencyDialer(String phoneNumber) async {
  final normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  if (normalized.isEmpty) {
    return false;
  }

  final uri = Uri(scheme: 'tel', path: normalized);
  if (!await canLaunchUrl(uri)) {
    return false;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Auto-dials [phoneNumber] when permitted; falls back to the dialer.
Future<bool> launchEmergencyCall(String phoneNumber) async {
  final normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  if (normalized.isEmpty) {
    return false;
  }

  if (!kIsWeb && Platform.isAndroid) {
    final granted = await phoneCallPermissionRequester();
    if (granted) {
      try {
        final placed = await _emergencyCallChannel.invokeMethod<bool>(
          'call',
          {'number': normalized},
        );
        if (placed == true) {
          return true;
        }
      } on PlatformException {
        // Fall through to dialer.
      }
    }
    return launchEmergencyDialer(normalized);
  }

  // iOS and other platforms: tel: starts the call on iPhone.
  return launchEmergencyDialer(normalized);
}
