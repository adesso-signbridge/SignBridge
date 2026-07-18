/// Nano Banana (Gemini) 2D gloss-image generation via the gloss worker.
abstract final class GlossImageConfig {
  static const workerUrl = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_WORKER_URL',
    defaultValue: 'https://signbridge-gloss.signbridge-adesso.workers.dev',
  );

  static const sharedKey = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_SHARED_KEY',
    defaultValue: '',
  );

  /// Enable Banana-generated 2D images per gloss instead of Veo video.
  static const enabled = bool.fromEnvironment(
    'BANANA_GLOSS_IMAGES',
    defaultValue: true,
  );

  static bool get isConfigured => workerUrl.trim().isNotEmpty && enabled;
}
