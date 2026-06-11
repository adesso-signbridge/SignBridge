import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/speech_error_mapper.dart';

void main() {
  test('maps permission errors to actionable guidance', () {
    final message = SpeechErrorMapper.userMessage('error_permission');
    expect(message, contains('Google'));
    expect(message, contains('Voice input'));
  });

  test('maps language errors to voice input guidance', () {
    final message = SpeechErrorMapper.userMessage('error_language_unavailable');
    expect(message, contains('Speech services by Google'));
  });
}
