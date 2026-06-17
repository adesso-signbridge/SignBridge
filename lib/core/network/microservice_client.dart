/// HTTP client for remote microservice endpoints.
///
/// Each backend service owns its base URL; the app calls them independently.
abstract final class MicroserviceEndpoints {
  static const String homeBase = String.fromEnvironment(
    'HOME_SERVICE_URL',
    defaultValue: 'https://api.signbridge.local/home',
  );
  static const String translateBase = String.fromEnvironment(
    'TRANSLATE_SERVICE_URL',
    defaultValue: 'https://api.signbridge.local/translate',
  );
  static const String phrasesBase = String.fromEnvironment(
    'PHRASES_SERVICE_URL',
    defaultValue: 'https://api.signbridge.local/phrases',
  );
  static const String sosBase = String.fromEnvironment(
    'SOS_SERVICE_URL',
    defaultValue: 'https://api.signbridge.local/sos',
  );
  static const String settingsBase = String.fromEnvironment(
    'SETTINGS_SERVICE_URL',
    defaultValue: 'https://api.signbridge.local/settings',
  );
  static const String glossWorkerUrl = String.fromEnvironment(
    'CLOUDFLARE_GLOSS_WORKER_URL',
    defaultValue: '',
  );
}

class MicroserviceClient {
  const MicroserviceClient();

  Future<Map<String, dynamic>> get(String baseUrl, String path) async {
    // Remote calls will be wired when backend microservices are available.
    throw UnimplementedError('GET $baseUrl$path');
  }
}
