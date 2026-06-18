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
          'modelUsed': 'gemini-3.5-flash',
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
    expect(result.duration, const Duration(milliseconds: 4500));
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
}
