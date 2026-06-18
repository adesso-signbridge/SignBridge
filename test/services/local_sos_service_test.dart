import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/sos/emergency_config.dart';
import 'package:sign_bridge/services/sos/local_sos_service.dart';

import '../services/mock_phrase_speech_service.dart';

void main() {
  group('EmergencyConfig', () {
    test('uses 112 for supported app languages', () {
      expect(EmergencyConfig.emergencyNumberFor('ENG'), '112');
      expect(EmergencyConfig.emergencyNumberFor('ML'), '112');
      expect(EmergencyConfig.emergencyNumberFor('HI'), '112');
      expect(EmergencyConfig.emergencyNumberFor('TA'), '112');
    });

    test('returns localized SOS messages', () {
      expect(
        EmergencyConfig.sosMessageFor('ENG'),
        contains('I need help immediately'),
      );
      expect(
        EmergencyConfig.sosMessageFor('ML'),
        contains('എനിക്ക്'),
      );
    });
  });

  group('LocalSosService', () {
    test('callEmergency opens dialer with configured number', () async {
      String? dialedNumber;
      final service = LocalSosService(
        dialEmergency: (number) async {
          dialedNumber = number;
          return true;
        },
      );

      final result = await service.callEmergency(languageCode: 'ENG');

      expect(result.ok, isTrue);
      expect(result.emergencyNumber, '112');
      expect(dialedNumber, '112');
    });

    test('activateSos speaks message then auto-calls', () async {
      final speech = MockPhraseSpeechService();
      String? dialedNumber;
      final service = LocalSosService(
        phraseSpeech: speech,
        dialEmergency: (number) async {
          dialedNumber = number;
          return true;
        },
      );

      final result = await service.activateSos(languageCode: 'ENG');

      expect(result.ok, isTrue);
      expect(result.emergencyNumber, '112');
      expect(dialedNumber, '112');
      expect(speech.lastSpokenText, EmergencyConfig.sosMessageFor('ENG'));
      expect(speech.lastLanguageCode, 'ENG');
    });

    test('returns failure when dialer cannot open', () async {
      final service = LocalSosService(
        dialEmergency: (_) async => false,
      );

      final result = await service.callEmergency(languageCode: 'ENG');

      expect(result.ok, isFalse);
      expect(result.errorMessage, isNotEmpty);
    });
  });
}
