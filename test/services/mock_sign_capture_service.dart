import 'package:sign_bridge/services/translate/sign_capture_service.dart';

final class MockSignCaptureService implements SignCaptureService {
  String? lastVideoPath;
  String? lastLanguageCode;
  Duration analyzeDelay = Duration.zero;

  @override
  String get serviceName => 'mock-sign-capture';

  @override
  SignCaptureResult peekResult(String languageCode) {
    return const SignCaptureResult(
      text: 'My name is Alex. I am deaf.',
      duration: Duration(seconds: 60),
      glossSequence: ['MY', 'NAME', 'ALEX', 'ME', 'DEAF'],
    );
  }

  @override
  Future<SignCaptureResult> analyzeRecording({
    required String videoPath,
    required String languageCode,
    Duration recordingDuration = Duration.zero,
    String? conversationContext,
  }) async {
    lastVideoPath = videoPath;
    lastLanguageCode = languageCode;
    if (analyzeDelay > Duration.zero) {
      await Future<void>.delayed(analyzeDelay);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return peekResult(languageCode).copyWith(videoPath: videoPath);
  }
}
