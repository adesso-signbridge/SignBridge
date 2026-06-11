import '../../core/services/microservice.dart';

import 'sign_capture_result.dart';

export 'sign_capture_result.dart';

/// Analyzes recorded sign-language video and returns spoken text.
abstract class SignCaptureService implements Microservice {
  /// Processes a finished recording file and returns recognized speech text.
  Future<SignCaptureResult> analyzeRecording({
    required String videoPath,
    required String languageCode,
  });

  /// Sample payload for simulators and tests.
  SignCaptureResult peekResult(String languageCode);
}
