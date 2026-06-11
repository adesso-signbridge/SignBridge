import 'phrases_service.dart';

final class LocalPhrasesService implements PhrasesService {
  @override
  String get serviceName => 'phrases-service';

  @override
  Future<String> getStatusMessage() async => 'Phrases';
}
