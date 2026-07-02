import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloudflare_gloss_config.dart';
import 'gloss_cloud_result.dart';
import 'gloss_service.dart';
import 'gloss_spoken_language.dart';

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
    required String languageCode,
    String? spokenLanguage,
  }) async {
    final result = await requestGlossDetail(
      jobId: jobId,
      caption: caption,
      signLanguage: signLanguage,
      languageCode: languageCode,
      spokenLanguage: spokenLanguage,
    );
    return result.glossSequence;
  }

  Future<GlossCloudResult> requestGlossDetail({
    required String jobId,
    required String caption,
    required String signLanguage,
    required String languageCode,
    String? spokenLanguage,
    List<String> priorGlossSequence = const [],
  }) async {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      return const GlossCloudResult(glossSequence: []);
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
            'languageCode': languageCode.trim().toUpperCase(),
            'spokenLanguage':
                spokenLanguage?.trim() ??
                GlossSpokenLanguage.nameFor(languageCode),
            'stitchVideo': true,
            if (priorGlossSequence.isNotEmpty)
              'priorGlossSequence': priorGlossSequence,
          }),
        )
        .timeout(const Duration(seconds: 30));

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

    final modelUsed = decoded['modelUsed'];
    if (modelUsed is String && modelUsed.trim().isNotEmpty) {
      debugPrint(
        '[SignBridge/Gloss] Gemini model: ${modelUsed.trim()} '
        '(caption gloss, jobId=$jobId)',
      );
    } else {
      debugPrint(
        '[SignBridge/Gloss] Cloud gloss ok (model unknown, jobId=$jobId)',
      );
    }

    final stitchedVideoUrl = decoded['stitchedVideoUrl'];
    if (stitchedVideoUrl is String && stitchedVideoUrl.trim().isNotEmpty) {
      debugPrint(
        '[SignBridge/Gloss] avatar stitched video: ${stitchedVideoUrl.trim()}',
      );
    } else {
      final stitchError = decoded['stitchError'];
      if (stitchError is String && stitchError.trim().isNotEmpty) {
        debugPrint('[SignBridge/Gloss] stitch skipped: $stitchError');
      }
    }

    final glossRaw = decoded['glossSequence'];
    if (glossRaw is! List) {
      return const GlossCloudResult(glossSequence: []);
    }

    final glossSequence = glossRaw
        .map((value) => '$value'.trim().toUpperCase())
        .where((token) =>
            token.isNotEmpty &&
            token != 'GLOSSSEQUENCE' &&
            token != 'GLOSSEQUENCE')
        .toList();

    final stitched = decoded['stitchedVideoUrl'];
    return GlossCloudResult(
      glossSequence: glossSequence,
      stitchedVideoUrl: stitched is String && stitched.trim().isNotEmpty
          ? stitched.trim()
          : null,
    );
  }

  void dispose() {
    _client.close();
  }
}
