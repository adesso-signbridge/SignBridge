import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloudflare_sign_config.dart';
import 'sign_capture_config.dart';
import 'sign_capture_service.dart';
import 'sign_language_system.dart';

/// Remote sign recognition via the Cloudflare Worker and Gemini video models.
final class CloudflareSignCaptureService implements SignCaptureService {
  CloudflareSignCaptureService({
    String? workerUrl,
    String? sharedKey,
    http.Client? client,
  })  : _workerUrl = (workerUrl ?? CloudflareSignConfig.workerUrl).trim(),
        _sharedKey = sharedKey ?? CloudflareSignConfig.sharedKey,
        _client = client ?? http.Client();

  final String _workerUrl;
  final String _sharedKey;
  final http.Client _client;

  @override
  String get serviceName => 'cloudflare-sign-capture-service';

  bool get isConfigured => _workerUrl.isNotEmpty;

  @override
  SignCaptureResult peekResult(String languageCode) {
    return SignCaptureResult(
      text: '',
      duration: Duration.zero,
    );
  }

  @override
  Future<SignCaptureResult> analyzeRecording({
    required String videoPath,
    required String languageCode,
    Duration recordingDuration = Duration.zero,
    String? conversationContext,
  }) async {
    if (!isConfigured) {
      throw StateError('Cloudflare sign worker URL is not configured');
    }

    final file = File(videoPath);
    if (!await file.exists()) {
      throw StateError('Sign recording not found: $videoPath');
    }

    final fileSize = await file.length();
    if (fileSize > SignCaptureConfig.maxUploadBytes) {
      throw HttpException(
        'Video too large (max ${SignCaptureConfig.maxUploadBytes ~/ (1024 * 1024)} MB)',
      );
    }

    final context = conversationContext?.trim();
    final urls = _workerUrls();
    Object? lastError;
    for (var index = 0; index < urls.length; index++) {
      final url = urls[index];
      try {
        return await _analyzeAtWorker(
          workerUrl: url,
          videoPath: videoPath,
          languageCode: languageCode,
          recordingDuration: recordingDuration,
          conversationContext: context,
        );
      } on Object catch (error) {
        lastError = error;
        final hasAlternate = index < urls.length - 1;
        if (hasAlternate && _shouldTryNextWorker(error)) {
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? StateError('Sign worker unavailable');
  }

  List<String> _workerUrls() {
    final urls = <String>[];
    final primary = _workerUrl.trim();
    if (primary.isNotEmpty) {
      urls.add(primary);
    }
    final legacy = CloudflareSignConfig.legacyWorkerUrl.trim();
    if (legacy.isNotEmpty && !urls.contains(legacy)) {
      urls.add(legacy);
    }
    return urls;
  }

  bool _shouldTryNextWorker(Object error) {
    if (error is HttpException) {
      final status = _httpStatusFromException(error);
      // Only fail over when the worker endpoint itself is missing — not when
      // Gemini returns 404 inside a 502 response body.
      return status == 404 || status == 1042;
    }
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    return false;
  }

  static int? _httpStatusFromException(HttpException error) {
    final match = RegExp(r'Sign worker (\d+):').firstMatch(error.message);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  Future<SignCaptureResult> _analyzeAtWorker({
    required String workerUrl,
    required String videoPath,
    required String languageCode,
    required Duration recordingDuration,
    String? conversationContext,
  }) async {
    final signLanguage =
        SignLanguageSystem.forSpokenLanguage(languageCode).label;
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();

    final request = http.MultipartRequest('POST', Uri.parse(workerUrl))
      ..fields['jobId'] = jobId
      ..fields['languageCode'] = languageCode
      ..fields['signLanguage'] = signLanguage
      ..fields['durationMs'] = '${recordingDuration.inMilliseconds}';
    if (conversationContext != null && conversationContext.isNotEmpty) {
      request.fields['conversationContext'] = conversationContext;
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'video',
        videoPath,
        filename: _videoUploadFilename(videoPath),
      ),
    );

    if (_sharedKey.isNotEmpty) {
      request.headers['X-SignBridge-Key'] = _sharedKey;
    }

    final streamed = await _client.send(request).timeout(
      SignCaptureConfig.workerRequestTimeout,
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Sign worker ${response.statusCode}: ${response.body}',
        uri: Uri.parse(workerUrl),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Unexpected sign worker response: ${response.body}',
      );
    }

    if (decoded['ok'] != true) {
      final detail = decoded['detail'] ?? decoded['error'] ?? 'unknown error';
      throw HttpException(
        'Sign worker failed: $detail',
        uri: Uri.parse(workerUrl),
      );
    }

    final text = '${decoded['text'] ?? ''}'.trim();
    if (text.isEmpty) {
      throw HttpException(
        'Sign worker returned empty text',
        uri: Uri.parse(workerUrl),
      );
    }

    final glossSequence = _parseGlossSequence(decoded['glossSequence']);

    final durationMs = decoded['durationMs'];
    final duration = durationMs is num && durationMs > 0
        ? Duration(milliseconds: durationMs.round())
        : recordingDuration;

    final modelUsed = decoded['modelUsed'];
    final modelLabel = modelUsed is String && modelUsed.trim().isNotEmpty
        ? modelUsed.trim()
        : null;

    if (modelLabel != null) {
      debugPrint(
        '[SignBridge/SignCapture] model: $modelLabel (video→text, jobId=$jobId)',
      );
    } else {
      debugPrint(
        '[SignBridge/SignCapture] model unknown (video→text, jobId=$jobId)',
      );
    }

    return SignCaptureResult(
      text: text,
      duration: duration,
      glossSequence: glossSequence,
      videoPath: videoPath,
      modelUsed: modelLabel,
    );
  }

  static List<String> _parseGlossSequence(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .map((value) => '$value'.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  void dispose() {
    _client.close();
  }

  static String _videoUploadFilename(String videoPath) {
    final name = videoPath.split('/').last;
    if (name.contains('.')) {
      return name;
    }
    final lower = videoPath.toLowerCase();
    if (lower.contains('.mov')) {
      return '$name.mov';
    }
    return '$name.mp4';
  }
}
