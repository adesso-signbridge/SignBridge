/// Sign avatar playback mode for the app build.
abstract final class SignPlaybackConfig {
  /// Static illustration only — no R2 clips, Veo video, or sign overlays.
  static const imagesOnly = bool.fromEnvironment(
    'SIGN_IMAGES_ONLY',
    defaultValue: true,
  );

  /// Generate a Gemini Veo reference video when the user taps Sign (Speak for me).
  static const veoOnSignTap = bool.fromEnvironment(
    'VEO_ON_SIGN_TAP',
    defaultValue: true,
  );

  static bool get veoEnabled => veoOnSignTap || !imagesOnly;
}
