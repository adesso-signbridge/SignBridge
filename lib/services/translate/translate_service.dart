import '../../core/services/microservice.dart';

abstract class TranslateService implements Microservice {
  Future<String> getStatusMessage();
}
