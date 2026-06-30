import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sign_asset_remote_config.dart';

/// Remote manifest and batch clip URL resolution via the sign-assets worker.
abstract final class SignAssetRemoteApi {
  static const _timeout = Duration(seconds: 12);

  static Future<Map<String, dynamic>?> fetchManifest() async {
    final base = SignAssetRemoteConfig.baseUrl;
    if (base.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$base/manifest.json');
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Manifest ${response.statusCode}', uri: uri);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected manifest payload from $uri');
    }
    return decoded;
  }

  /// Resolves bundled asset paths to HTTPS playback URLs via POST /clips.
  static Future<Map<String, String>> resolveClipUrls(
    List<String> assetPaths,
  ) async {
    final base = SignAssetRemoteConfig.baseUrl;
    if (base.isEmpty || assetPaths.isEmpty) {
      return {};
    }

    final uri = Uri.parse('$base/clips');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'paths': assetPaths}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Clips ${response.statusCode}', uri: uri);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
      throw FormatException('Clips request failed: ${response.body}');
    }

    final clips = decoded['clips'];
    if (clips is! List) {
      return {};
    }

    final urls = <String, String>{};
    for (final entry in clips) {
      if (entry is! Map) {
        continue;
      }
      final assetPath = entry['assetPath'];
      final url = entry['url'];
      if (assetPath is String &&
          assetPath.isNotEmpty &&
          url is String &&
          url.isNotEmpty) {
        urls[assetPath] = url;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[SignBridge/SignAsset] batch clips resolved ${urls.length}/${assetPaths.length}',
      );
    }
    return urls;
  }
}
