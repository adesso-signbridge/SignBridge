import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign_bridge/services/gloss/cloudflare_gloss_service.dart';

void main() {
  test('requestGloss parses worker glossSequence', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://gloss.example.com/');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['caption'], 'Hello there');
      expect(body['signLanguage'], 'ASL');
      return http.Response(
        jsonEncode({
          'ok': true,
          'jobId': 'job-1',
          'glossSequence': ['HELLO', 'THERE'],
        }),
        200,
      );
    });

    final service = CloudflareGlossService(
      workerUrl: 'https://gloss.example.com/',
      client: client,
    );

    final gloss = await service.requestGloss(
      jobId: 'job-1',
      caption: 'Hello there',
      signLanguage: 'ASL',
      languageCode: 'ENG',
    );

    expect(gloss, ['HELLO', 'THERE']);
    service.dispose();
  });

  test('requestGloss sends language metadata for ISL', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['signLanguage'], 'ISL');
      expect(body['languageCode'], 'TA');
      expect(body['spokenLanguage'], 'தமிழ்');
      return http.Response(
        jsonEncode({'ok': true, 'glossSequence': ['YOU', 'HOW']}),
        200,
      );
    });

    final service = CloudflareGlossService(
      workerUrl: 'https://gloss.example.com/',
      client: client,
    );

    final gloss = await service.requestGloss(
      jobId: 'job-ta',
      caption: 'நீங்கள் எப்படி இருக்கிறீர்கள்?',
      signLanguage: 'ISL',
      languageCode: 'TA',
      spokenLanguage: 'தமிழ்',
    );

    expect(gloss, ['YOU', 'HOW']);
    service.dispose();
  });

  test('requestGloss sends shared key header when configured', () async {
    final client = MockClient((request) async {
      expect(request.headers['X-SignBridge-Key'], 'secret-key');
      return http.Response(
        jsonEncode({'ok': true, 'glossSequence': ['ME', 'HELLO']}),
        200,
      );
    });

    final service = CloudflareGlossService(
      workerUrl: 'https://gloss.example.com/',
      sharedKey: 'secret-key',
      client: client,
    );

    final gloss = await service.requestGloss(
      jobId: 'job-2',
      caption: 'Hi',
      signLanguage: 'ASL',
      languageCode: 'ENG',
    );

    expect(gloss, ['ME', 'HELLO']);
    service.dispose();
  });
}
