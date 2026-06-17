/// Worker URL and optional shared key for cloud gloss requests.
abstract final class CloudflareGlossConfig {
  static const workerUrl = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_WORKER_URL',
    defaultValue: '',
  );

  static const sharedKey = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_SHARED_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => workerUrl.trim().isNotEmpty;
}
