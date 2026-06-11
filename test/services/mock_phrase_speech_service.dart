import 'package:sign_bridge/services/phrases/phrase_speech_service.dart';

final class MockPhraseSpeechService implements PhraseSpeechService {
  String? lastSpokenText;
  String? lastLanguageCode;

  @override
  Future<void> speak(String text, String languageCode) async {
    lastSpokenText = text;
    lastLanguageCode = languageCode;
  }

  @override
  Future<void> stop() async {}
}
