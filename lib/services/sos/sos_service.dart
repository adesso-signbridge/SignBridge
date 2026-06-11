import '../../core/services/microservice.dart';

abstract class SosService implements Microservice {
  Future<String> getStatusMessage();
}
