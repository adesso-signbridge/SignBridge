/// Sign avatar playback mode for the app build.
abstract final class SignPlaybackConfig {
  /// Prefer 2D images (Banana per-gloss) over R2 clips / Veo video overlays.
  static const imagesOnly = bool.fromEnvironment(
    'SIGN_IMAGES_ONLY',
    defaultValue: true,
  );
}
