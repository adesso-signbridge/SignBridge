/// Cloud Veo 3.1 sign-video generation (Adobe Firefly-style).
abstract final class VeoSignVideoConfig {
  static const workerUrl = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_WORKER_URL',
    defaultValue: 'https://signbridge-gloss.signbridge-adesso.workers.dev',
  );

  static const sharedKey = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_SHARED_KEY',
    defaultValue: '',
  );

  /// Enable Veo-generated avatar videos instead of R2 clip playback.
  static const enabled = bool.fromEnvironment(
    'VEO_SIGN_VIDEO',
    defaultValue: true,
  );

  static bool get isConfigured => workerUrl.trim().isNotEmpty && enabled;
}
