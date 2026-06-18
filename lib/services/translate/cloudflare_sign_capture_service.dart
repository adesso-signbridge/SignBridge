import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'cloudflare_sign_config.dart';
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
  }) async {
    if (!isConfigured) {
      throw StateError('Cloudflare sign worker URL is not configured');
    }

    final file = File(videoPath);
    if (!await file.exists()) {
      throw StateError('Sign recording not found: $videoPath');
    }

    final urls = _workerUrls();
    Object? lastError;
    for (final url in urls) {
      try {
        return await _analyzeAtWorker(
          workerUrl: url,
          videoPath: videoPath,
          languageCode: languageCode,
          recordingDuration: recordingDuration,
        );
      } on Object catch (error) {
        lastError = error;
        if (_shouldTryNextWorker(error)) {
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? StateError('Sign worker unavailable');
  }

  List<String> _workerUrls() {
    final urls = <String>{_workerUrl};
    if (_workerUrl != CloudflareSignConfig.legacyWorkerUrl) {
      urls.add(CloudflareSignConfig.legacyWorkerUrl);
    }
    return urls.where((url) => url.trim().isNotEmpty).toList();
  }

  bool _shouldTryNextWorker(Object error) {
    if (error is HttpException) {
      final message = error.message;
      return message.contains('404') ||
          message.contains('1042') ||
          message.contains('Sign worker unavailable');
    }
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    return false;
  }

  Future<SignCaptureResult> _analyzeAtWorker({
    required String workerUrl,
    required String videoPath,
    required String languageCode,
    required Duration recordingDuration,
  }) async {
    final signLanguage =
        SignLanguageSystem.forSpokenLanguage(languageCode).label;
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();

    final request = http.MultipartRequest('POST', Uri.parse(workerUrl))
      ..fields['jobId'] = jobId
      ..fields['languageCode'] = languageCode
      ..fields['signLanguage'] = signLanguage
      ..fields['durationMs'] = '${recordingDuration.inMilliseconds}'
      ..files.add(await http.MultipartFile.fromPath('video', videoPath));

    if (_sharedKey.isNotEmpty) {
      request.headers['X-SignBridge-Key'] = _sharedKey;
    }

    final streamed = await _client.send(request).timeout(
      const Duration(seconds: 90),
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

    final durationMs = decoded['durationMs'];
    final duration = durationMs is num && durationMs > 0
        ? Duration(milliseconds: durationMs.round())
        : recordingDuration;

    return SignCaptureResult(
      text: text,
      duration: duration,
      videoPath: videoPath,
    );
  }

  void dispose() {
    _client.close();
  }
}
