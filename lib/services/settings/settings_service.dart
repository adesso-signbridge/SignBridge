import '../../core/services/microservice.dart';

abstract class SettingsService implements Microservice {
  Future<String> getStatusMessage();
}
