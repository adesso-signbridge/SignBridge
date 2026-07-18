import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gloss_image_config.dart';
import 'gloss_image_result.dart';

/// Requests Nano Banana 2D images for each gloss on the gloss worker.
final class CloudflareGlossImageService {
  CloudflareGlossImageService({
    String? workerUrl,
    String? sharedKey,
    http.Client? client,
  }) : _workerBase = _normalizeBase(workerUrl ?? GlossImageConfig.workerUrl),
       _sharedKey = sharedKey ?? GlossImageConfig.sharedKey,
       _client = client ?? http.Client();

  final String _workerBase;
  final String _sharedKey;
  final http.Client _client;

  bool get isConfigured => _workerBase.isNotEmpty && GlossImageConfig.enabled;

  Future<GlossImageResult> generate({
    required String jobId,
    required List<String> glossSequence,
    required String signLanguage,
  }) async {
    final decoded = await _postJson('$_workerBase/image/generate', {
      'jobId': jobId,
      'signLanguage': signLanguage,
      'glossSequence': glossSequence,
    });
    return _parseResult(decoded);
  }

  Future<GlossImageResult?> waitUntilReady({
    required String jobId,
    required List<String> glossSequence,
    required String signLanguage,
  }) async {
    final result = await generate(
      jobId: jobId,
      glossSequence: glossSequence,
      signLanguage: signLanguage,
    );

    if (result.model != null && result.model!.trim().isNotEmpty) {
      debugPrint(
        '[SignBridge/Banana] model: ${result.model!.trim()} (jobId=$jobId)',
      );
    }

    if (result.isReady) {
      debugPrint(
        '[SignBridge/Banana] ready ${result.imageUrls.length} image(s)',
      );
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(Uri.parse(url), headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(minutes: 3));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Banana image ${response.statusCode}: ${response.body}',
        uri: Uri.parse(url),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected Banana response: ${response.body}');
    }
    if (decoded['ok'] == false) {
      final detail = decoded['detail'] ?? decoded['error'] ?? 'unknown error';
      throw HttpException(
        'Banana image failed: $detail',
        uri: Uri.parse(url),
      );
    }
    return decoded;
  }

  GlossImageResult _parseResult(Map<String, dynamic> decoded) {
    final rawImages = decoded['images'];
    final images = <GlossImageItem>[];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is! Map) {
          continue;
        }
        final gloss = '${item['gloss'] ?? ''}'.trim();
        final imageUrl = '${item['imageUrl'] ?? ''}'.trim();
        if (gloss.isEmpty || imageUrl.isEmpty) {
          continue;
        }
        images.add(
          GlossImageItem(
            gloss: gloss,
            imageUrl: imageUrl,
            cached: item['cached'] == true,
          ),
        );
      }
    }

    final rawUrls = decoded['imageUrls'];
    final imageUrls = <String>[];
    if (rawUrls is List) {
      for (final url in rawUrls) {
        final trimmed = '$url'.trim();
        if (trimmed.isNotEmpty) {
          imageUrls.add(trimmed);
        }
      }
    } else {
      imageUrls.addAll(images.map((item) => item.imageUrl));
    }

    return GlossImageResult(
      status: '${decoded['status'] ?? 'unknown'}',
      imageUrls: imageUrls,
      images: images,
      model: decoded['model'] is String ? decoded['model'] as String : null,
      cached: images.isNotEmpty && images.every((item) => item.cached),
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
