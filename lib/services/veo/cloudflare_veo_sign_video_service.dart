import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'veo_sign_video_config.dart';
import 'veo_sign_video_result.dart';

/// Starts and polls Veo 3.1 sign-video jobs on the gloss worker.
final class CloudflareVeoSignVideoService {
  CloudflareVeoSignVideoService({
    String? workerUrl,
    String? sharedKey,
    http.Client? client,
  })  : _workerBase = _normalizeBase(workerUrl ?? VeoSignVideoConfig.workerUrl),
        _sharedKey = sharedKey ?? VeoSignVideoConfig.sharedKey,
        _client = client ?? http.Client();

  final String _workerBase;
  final String _sharedKey;
  final http.Client _client;

  bool get isConfigured => _workerBase.isNotEmpty && VeoSignVideoConfig.enabled;

  Future<VeoSignVideoResult> start({
    required String jobId,
    required String caption,
    required List<String> glossSequence,
    required String signLanguage,
  }) async {
    final decoded = await _postJson(
      '$_workerBase/veo/generate',
      {
        'jobId': jobId,
        'caption': caption.trim(),
        'signLanguage': signLanguage,
        'glossSequence': glossSequence,
      },
    );
    return _parseResult(decoded);
  }

  Future<VeoSignVideoResult> poll({
    required String operationName,
    required String jobId,
    required String caption,
    required List<String> glossSequence,
    required String signLanguage,
  }) async {
    final uri = Uri.parse('$_workerBase/veo/status').replace(
      queryParameters: {
        'operation': operationName,
        'jobId': jobId,
        'caption': caption.trim(),
        'signLanguage': signLanguage,
        'glossSequence': jsonEncode(glossSequence),
      },
    );

    final response = await _client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Veo status ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected Veo status response: ${response.body}');
    }
    return _parseResult(decoded);
  }

  Future<VeoSignVideoResult?> waitUntilReady({
    required String jobId,
    required String caption,
    required List<String> glossSequence,
    required String signLanguage,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final started = await start(
      jobId: jobId,
      caption: caption,
      glossSequence: glossSequence,
      signLanguage: signLanguage,
    );

    if (started.model != null && started.model!.trim().isNotEmpty) {
      debugPrint('[SignBridge/Veo] model: ${started.model!.trim()} (jobId=$jobId)');
    }

    if (started.isReady) {
      debugPrint('[SignBridge/Veo] cached video: ${started.videoUrl}');
      return started;
    }

    final operationName = started.operationName;
    if (operationName == null || operationName.isEmpty) {
      return null;
    }

    final deadline = DateTime.now().add(timeout);
    var latest = started;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(milliseconds: latest.pollAfterMs));
      latest = await poll(
        operationName: operationName,
        jobId: jobId,
        caption: caption,
        glossSequence: glossSequence,
        signLanguage: signLanguage,
      );
      if (latest.isReady) {
        debugPrint('[SignBridge/Veo] generated video: ${latest.videoUrl}');
        return latest;
      }
      if (!latest.isProcessing) {
        return null;
      }
    }

    debugPrint('[SignBridge/Veo] timed out waiting for video (jobId=$jobId)');
    return null;
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Veo generate ${response.statusCode}: ${response.body}',
        uri: Uri.parse(url),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected Veo response: ${response.body}');
    }
    if (decoded['ok'] == false) {
      final detail = decoded['detail'] ?? decoded['error'] ?? 'unknown error';
      throw HttpException('Veo generate failed: $detail', uri: Uri.parse(url));
    }
    return decoded;
  }

  VeoSignVideoResult _parseResult(Map<String, dynamic> decoded) {
    final pollAfter = decoded['pollAfterMs'];
    return VeoSignVideoResult(
      status: '${decoded['status'] ?? 'unknown'}',
      videoUrl: decoded['videoUrl'] is String ? decoded['videoUrl'] as String : null,
      operationName: decoded['operationName'] is String
          ? decoded['operationName'] as String
          : null,
      prompt: decoded['prompt'] is String ? decoded['prompt'] as String : null,
      model: decoded['model'] is String ? decoded['model'] as String : null,
      pollAfterMs: pollAfter is int ? pollAfter : 8000,
      cached: decoded['cached'] == true,
    );
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (_sharedKey.isNotEmpty) {
      headers['X-SignBridge-Key'] = _sharedKey;
    }
    return headers;
  }

  static String _normalizeBase(String raw) {
    return raw.trim().replaceAll(RegExp(r'/+$'), '');
  }

  void dispose() {
    _client.close();
  }
}
