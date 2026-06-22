import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sign_bridge/services/translate/cloudflare_sign_capture_service.dart';

void main() {
  test('analyzeRecording parses worker text response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://sign.example.com/');
      expect(request.headers['X-SignBridge-Key'], 'secret-key');
      return http.Response(
        jsonEncode({
          'ok': true,
          'jobId': 'job-1',
          'text': 'My name is Alex. I am deaf.',
          'glossSequence': ['MY', 'NAME', 'ALEX', 'ME', 'DEAF'],
          'modelUsed': 'gemini-3.5-flash+gemini-3.1-flash-lite',
          'durationMs': 4500,
        }),
        200,
      );
    });

    final tempDir = await Directory.systemTemp.createTemp('sign_capture_test');
    final videoFile = File('${tempDir.path}/sample.mp4');
    await videoFile.writeAsBytes(const [0, 1, 2]);

    final service = CloudflareSignCaptureService(
      workerUrl: 'https://sign.example.com/',
      sharedKey: 'secret-key',
      client: client,
    );

    final result = await service.analyzeRecording(
      videoPath: videoFile.path,
      languageCode: 'ENG',
      recordingDuration: const Duration(seconds: 4),
    );

    expect(result.text, 'My name is Alex. I am deaf.');
    expect(result.glossSequence, ['MY', 'NAME', 'ALEX', 'ME', 'DEAF']);
    expect(result.duration, const Duration(milliseconds: 4500));
    expect(result.modelUsed, 'gemini-3.5-flash+gemini-3.1-flash-lite');
    expect(result.videoPath, videoFile.path);
    service.dispose();
    await tempDir.delete(recursive: true);
  });

  test('analyzeRecording throws when worker returns empty text', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'ok': true, 'text': ''}),
        200,
      );
    });

    final tempDir = await Directory.systemTemp.createTemp('sign_capture_test');
    final videoFile = File('${tempDir.path}/sample.mp4');
    await videoFile.writeAsBytes(const [0, 1, 2]);

    final service = CloudflareSignCaptureService(
      workerUrl: 'https://sign.example.com/',
      client: client,
    );

    await expectLater(
      service.analyzeRecording(
        videoPath: videoFile.path,
        languageCode: 'ENG',
      ),
      throwsA(isA<HttpException>()),
    );
    service.dispose();
    await tempDir.delete(recursive: true);
  });

  test('does not treat Gemini 404 inside 502 as missing worker', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return http.Response(
        jsonEncode({
          'error': 'Sign recognition failed',
          'detail':
              'Error: Gemini 404: {"error":{"code":404,"message":"models/gemini-3.5-flash not found"}}',
        }),
        502,
      );
    });

    final tempDir = await Directory.systemTemp.createTemp('sign_capture_test');
    final videoFile = File('${tempDir.path}/sample.mp4');
    await videoFile.writeAsBytes(const [0, 1, 2]);

    final service = CloudflareSignCaptureService(
      workerUrl: 'https://sign.example.com/sign',
      client: client,
    );

    await expectLater(
      service.analyzeRecording(
        videoPath: videoFile.path,
        languageCode: 'ENG',
      ),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          contains('Sign worker 502'),
        ),
      ),
    );
    expect(requestCount, 1);
    service.dispose();
    await tempDir.delete(recursive: true);
  });
}
