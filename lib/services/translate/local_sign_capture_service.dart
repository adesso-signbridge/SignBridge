import 'sign_capture_service.dart';

final class LocalSignCaptureService implements SignCaptureService {
  @override
  String get serviceName => 'sign-capture-service';

  static const _mockByLanguage = <String, String>{
    'ENG': 'My name is Alex. I am deaf.',
    'ML': 'എന്റെ പേര് അലക്സ്. ഞാൻ ബധിരനാണ്.',
    'HI': 'मेरा नाम एलेक्स है। मैं बहरा हूँ।',
    'TA': 'என் பெயர் அலெக்ஸ். நான் செவிடர்.',
  };

  @override
  SignCaptureResult peekResult(String languageCode) {
    return SignCaptureResult(
      text: _mockByLanguage[languageCode] ?? _mockByLanguage['ENG']!,
      duration: const Duration(seconds: 60),
    );
  }

  @override
  Future<SignCaptureResult> analyzeRecording({
    required String videoPath,
    required String languageCode,
    Duration recordingDuration = Duration.zero,
  }) async {
    // Placeholder for on-device / backend sign recognition from [videoPath].
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    return peekResult(languageCode).copyWith(videoPath: videoPath);
  }
}
