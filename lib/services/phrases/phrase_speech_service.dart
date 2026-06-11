/// Speaks a phrase aloud for the Speak-for-me flow.
abstract class PhraseSpeechService {
  Future<void> speak(String text, String languageCode);

  Future<void> stop();
}
