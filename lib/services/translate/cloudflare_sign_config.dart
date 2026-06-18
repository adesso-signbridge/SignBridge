/// Worker URL and optional shared key for cloud sign recognition.
abstract final class CloudflareSignConfig {
  static const workerUrl = String.fromEnvironment(
    'CLOUDFLARE_SIGN_WORKER_URL',
    defaultValue:
        'https://signbridge-gloss.signbridge-adesso.workers.dev/sign',
  );

  static const sharedKey = String.fromEnvironment(
    'CLOUDFLARE_SIGN_SHARED_KEY',
    defaultValue: '',
  );

  /// Legacy standalone sign worker URL tried when [workerUrl] is unavailable.
  static const legacyWorkerUrl =
      'https://signbridge-sign.signbridge-adesso.workers.dev';

  static bool get isConfigured => workerUrl.trim().isNotEmpty;
}
