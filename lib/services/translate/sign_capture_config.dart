/// Shared sign-video capture limits for the Talk → Sign flow.
abstract final class SignCaptureConfig {
  /// Minimum clip length sent to the sign recognition worker.
  static const minRecordingDuration = Duration(seconds: 2);

  /// Auto-stop recording after this duration to keep uploads small.
  static const maxRecordingDuration = Duration(seconds: 5);

  /// Reject clips larger than this before upload (worker limit is 10 MB).
  static const maxUploadBytes = 8 * 1024 * 1024;
}
