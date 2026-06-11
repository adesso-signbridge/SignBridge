import 'translate_service.dart';

final class LocalTranslateService implements TranslateService {
  @override
  String get serviceName => 'translate-service';

  @override
  Future<String> getStatusMessage() async => 'Translate';
}
