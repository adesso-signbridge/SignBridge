import '../../core/services/microservice.dart';
import 'sos_action_result.dart';

abstract class SosService implements Microservice {
  /// Opens the phone dialer to the local emergency number.
  Future<SosActionResult> callEmergency({required String languageCode});

  /// Speaks an SOS message aloud, then opens the emergency dialer.
  Future<SosActionResult> activateSos({required String languageCode});
}
