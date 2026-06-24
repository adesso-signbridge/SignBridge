import 'package:flutter/foundation.dart';

/// Base URL for signer videos hosted on Cloudflare R2 (sign-assets worker).
///
/// Set empty via `--dart-define=SIGN_ASSETS_BASE_URL=` to force bundled assets.
abstract final class SignAssetRemoteConfig {
  static const _defaultBaseUrl =
      'https://signbridge-sign-assets.signbridge-adesso.workers.dev';

  static const _envBaseUrl = String.fromEnvironment(
    'SIGN_ASSETS_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String? _testOverride;

  /// Remote worker origin without trailing slash.
  static String get baseUrl {
    final override = _testOverride;
    if (override != null) {
      return override;
    }
    return _envBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static bool get useRemote => baseUrl.isNotEmpty;

  @visibleForTesting
  static void setBaseUrlForTest(String? value) {
    _testOverride = value;
  }
}
