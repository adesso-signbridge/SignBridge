/// Supported sign-language systems for voice-to-sign translation.
enum SignLanguageSystem {
  /// American Sign Language — used for English speech.
  asl('ASL'),

  /// Indian Sign Language — used for Hindi, Tamil, Malayalam, and other Indian languages.
  isl('ISL');

  const SignLanguageSystem(this.label);

  final String label;

  static SignLanguageSystem forSpokenLanguage(String languageCode) {
    return switch (languageCode) {
      'ENG' => SignLanguageSystem.asl,
      'HI' || 'TA' || 'ML' => SignLanguageSystem.isl,
      _ => SignLanguageSystem.asl,
    };
  }
}
