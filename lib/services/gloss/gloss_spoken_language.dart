/// Spoken-language metadata sent with gloss requests (STT language, not sign system).
abstract final class GlossSpokenLanguage {
  static String nameFor(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'HI' => 'Hindi',
      'TA' => 'Tamil',
      'ML' => 'Malayalam',
      'ENG' => 'English',
      _ => 'English',
    };
  }

  static String scriptHintFor(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'HI' => 'Devanagari',
      'TA' => 'Tamil',
      'ML' => 'Malayalam',
      _ => 'Latin',
    };
  }
}
