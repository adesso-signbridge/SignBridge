import 'sos_service.dart';

final class LocalSosService implements SosService {
  @override
  String get serviceName => 'sos-service';

  @override
  Future<String> getStatusMessage() async => 'SOS';
}
