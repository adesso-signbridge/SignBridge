/// Shared sign-video capture limits for the Talk → Sign flow.
abstract final class SignCaptureConfig {
  /// Minimum clip length sent to the sign recognition worker.
  static const minRecordingDuration = Duration(seconds: 2);
}
