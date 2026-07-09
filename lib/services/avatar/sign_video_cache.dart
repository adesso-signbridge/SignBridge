import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'sign_playback_clip.dart';

/// Disk cache for remotely streamed signer clips.
abstract final class SignVideoCache {
  static const _cacheFolderName = 'sign_videos';
  static Directory? _cacheRoot;

  @visibleForTesting
  static Directory? testCacheRoot;

  @visibleForTesting
  static void setCacheRootForTest(Directory? directory) {
    testCacheRoot = directory;
    _cacheRoot = directory;
  }

  static Future<Directory> _cacheDirectory() async {
    if (testCacheRoot != null) {
      return testCacheRoot!;
    }
    _cacheRoot ??= await getApplicationCacheDirectory();
    final dir = Directory('${_cacheRoot!.path}/$_cacheFolderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String cacheFileName(String remoteUrl) {
    final uri = Uri.parse(remoteUrl);
    final fileName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'clip.mp4';
    final digest = remoteUrl.hashCode.abs().toRadixString(16);
    return '${digest}_$fileName';
  }

  static Future<String?> localPathIfCached(String remoteUrl) async {
    if (!remoteUrl.startsWith('http')) {
      return null;
    }
    final file = File(
      '${(await _cacheDirectory()).path}/${cacheFileName(remoteUrl)}',
    );
    if (await file.exists()) {
      final length = await file.length();
      if (length > 0) {
        return file.path;
      }
    }
    return null;
  }

  /// Downloads [remoteUrl] to cache; returns local file path when successful.
  static Future<String?> cacheRemoteClip(String remoteUrl) async {
    if (!remoteUrl.startsWith('http')) {
      return null;
    }

    final existing = await localPathIfCached(remoteUrl);
    if (existing != null) {
      return existing;
    }

    try {
      final response = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return null;
      }

      final file = File(
        '${(await _cacheDirectory()).path}/${cacheFileName(remoteUrl)}',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (kDebugMode) {
        debugPrint('[SignBridge/SignVideo] cached ${file.path}');
      }
      return file.path;
    } on Object catch (error) {
      debugPrint('[SignBridge/SignVideo] cache download failed ($error)');
      return null;
    }
  }

  /// Starts a background cache download after streaming playback.
  static void warmCacheInBackground(String remoteUrl) {
    if (!remoteUrl.startsWith('http')) {
      return;
    }
    unawaited(cacheRemoteClip(remoteUrl));
  }
}

/// Resolves the best local playback source for a clip (cache → remote → asset).
abstract final class SignVideoPlaybackSource {
  static Future<String> resolve(SignPlaybackClip clip) async {
    if (!clip.isRemote) {
      return clip.playbackUri;
    }

    final cached = await SignVideoCache.localPathIfCached(clip.playbackUri);
    if (cached != null) {
      return cached;
    }

    SignVideoCache.warmCacheInBackground(clip.playbackUri);
    return clip.playbackUri;
  }

  static Future<String> resolveForPrefetch(SignPlaybackClip clip) async {
    if (!clip.isRemote) {
      return clip.playbackUri;
    }

    final cached = await SignVideoCache.cacheRemoteClip(clip.playbackUri);
    return cached ?? clip.playbackUri;
  }
}
