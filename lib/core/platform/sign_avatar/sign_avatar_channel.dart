import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';

/// Bridges Flutter talk UI to native 3D sign avatar renderers on Android/iOS.
abstract final class SignAvatarChannel {
  static const _channel = MethodChannel('com.adesso.signbridge/sign_avatar');
  static const _invokeTimeout = Duration(seconds: 2);

  static bool get _supportsNativeAvatar {
    if (kIsWeb || _isFlutterTest) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static Future<void> playSign({
    required String signTokenId,
    required SignLanguageSystem system,
  }) async {
    if (!_supportsNativeAvatar) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('playSign', {
            'signTokenId': signTokenId,
            'system': system.name,
          })
          .timeout(_invokeTimeout);
    } on MissingPluginException {
      // Tests / unsupported embedders fall back to Flutter illustration.
    } on PlatformException {
      // Native renderer unavailable — illustration fallback remains visible.
    } on TimeoutException {
      // Native renderer busy — next pose update will retry.
    }
  }

  static Future<void> setIdle() async {
    if (!_supportsNativeAvatar) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setIdle').timeout(_invokeTimeout);
    } on MissingPluginException {
      // noop
    } on PlatformException {
      // noop
    } on TimeoutException {
      // noop
    }
  }
}

/// View type registered in native MainActivity / AppDelegate.
const signAvatarViewType = 'com.adesso.signbridge/sign_avatar_view';
