import 'settings_service.dart';

final class LocalSettingsService implements SettingsService {
  @override
  String get serviceName => 'settings-service';

  @override
  Future<String> getStatusMessage() async => 'Settings';
}
