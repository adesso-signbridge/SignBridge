import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'cloudflare_gloss_config.dart';
import 'gloss_service.dart';

/// Remote gloss generation via the Cloudflare Worker.
final class CloudflareGlossService implements GlossService {
  CloudflareGlossService({
    String? workerUrl,
    String? sharedKey,
    http.Client? client,
  })  : _workerUrl = (workerUrl ?? CloudflareGlossConfig.workerUrl).trim(),
        _sharedKey = sharedKey ?? CloudflareGlossConfig.sharedKey,
        _client = client ?? http.Client();

  final String _workerUrl;
  final String _sharedKey;
  final http.Client _client;

  @override
  String get serviceName => 'cloudflare-gloss-service';

  bool get isConfigured => _workerUrl.isNotEmpty;

  @override
  Future<List<String>> requestGloss({
    required String jobId,
    required String caption,
    required String signLanguage,
  }) async {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    if (!isConfigured) {
      throw StateError('Cloudflare gloss worker URL is not configured');
    }

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (_sharedKey.isNotEmpty) {
      headers['X-SignBridge-Key'] = _sharedKey;
    }

    final response = await _client
        .post(
          Uri.parse(_workerUrl),
          headers: headers,
          body: jsonEncode({
            'jobId': jobId,
            'caption': trimmed,
            'signLanguage': signLanguage,
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Gloss worker ${response.statusCode}: ${response.body}',
        uri: Uri.parse(_workerUrl),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected gloss worker response: ${response.body}');
    }

    if (decoded['ok'] != true) {
      final detail = decoded['detail'] ?? decoded['error'] ?? 'unknown error';
      throw HttpException('Gloss worker failed: $detail', uri: Uri.parse(_workerUrl));
    }

    final glossRaw = decoded['glossSequence'];
    if (glossRaw is! List) {
      return const [];
    }

    return glossRaw
        .map((value) => '$value'.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
