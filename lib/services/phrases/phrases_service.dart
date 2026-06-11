import '../../core/services/microservice.dart';

abstract class PhrasesService implements Microservice {
  Future<String> getStatusMessage();
}
