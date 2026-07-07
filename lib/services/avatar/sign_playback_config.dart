/// Sign avatar playback mode for the app build.
abstract final class SignPlaybackConfig {
  /// Static illustration only — no R2 clips, Veo video, or sign overlays.
  static const imagesOnly = bool.fromEnvironment(
    'SIGN_IMAGES_ONLY',
    defaultValue: true,
  );
}
