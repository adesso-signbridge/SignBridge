import '../../core/platform/emergency_dialer.dart';
import '../phrases/phrase_speech_service.dart';
import 'emergency_config.dart';
import 'sos_action_result.dart';
import 'sos_service.dart';

final class LocalSosService implements SosService {
  LocalSosService({
    this._phraseSpeech,
    EmergencyDialer? dialEmergency,
  }) : _dialEmergency = dialEmergency ?? launchEmergencyCall;

  final PhraseSpeechService? _phraseSpeech;
  final EmergencyDialer _dialEmergency;

  @override
  String get serviceName => 'sos-service';

  @override
  Future<SosActionResult> callEmergency({required String languageCode}) async {
    final number = EmergencyConfig.emergencyNumberFor(languageCode);
    final opened = await _dialEmergency(number);
    if (!opened) {
      return const SosActionResult.failure('Could not open phone dialer');
    }
    return SosActionResult.success(emergencyNumber: number);
  }

  @override
  Future<SosActionResult> activateSos({required String languageCode}) async {
    final number = EmergencyConfig.emergencyNumberFor(languageCode);
    final message = EmergencyConfig.sosMessageFor(languageCode);

    final speech = _phraseSpeech;
    if (speech != null) {
      await speech.speak(message, languageCode);
    }

    final opened = await _dialEmergency(number);
    if (!opened) {
      return const SosActionResult.failure('Could not place emergency call');
    }

    return SosActionResult.success(
      emergencyNumber: number,
      spokenMessage: message,
    );
  }
}
