/// Shared sign-video capture limits for the Talk → Sign flow.
abstract final class SignCaptureConfig {
  /// Minimum clip length sent to the sign recognition worker.
  static const minRecordingDuration = Duration(seconds: 2);

  /// Upper bound for clip length validation after the user taps Stop.
  static const maxRecordingDuration = Duration(seconds: 30);

  /// Reject clips larger than this before upload (worker limit is 10 MB).
  static const maxUploadBytes = 8 * 1024 * 1024;

  /// Max wait for sign worker upload + Gemini video analysis (mobile + slow API).
  static const workerRequestTimeout = Duration(seconds: 240);
}
