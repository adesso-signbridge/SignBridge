/// Emergency numbers and spoken SOS messages by app language.
abstract final class EmergencyConfig {
  static String emergencyNumberFor(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'ENG' => '112',
      'HI' || 'TA' || 'ML' => '112',
      _ => '112',
    };
  }

  static String sosMessageFor(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'ML' =>
        'എനിക്ക് ഉടനടി സഹായം ആവശ്യമാണ്. '
            'ഞാൻ ബധിരനാണ്, സംസാരിക്കാൻ കഴിയില്ല. '
            'ഇത് ഒരു അടിയന്തരാവസ്ഥയാണ്.',
      'HI' =>
        'मुझे तुरंत मदद चाहिए। '
            'मैं बहरा हूँ और बोल नहीं सकता। '
            'यह एक आपातकाल है।',
      'TA' =>
        'எனக்கு உடனடியாக உதவி தேவை. '
            'நான் செவிடர், பேச முடியாது. '
            'இது அவசர சூழ்நிலை.',
      _ =>
        'I need help immediately. '
            'I am deaf and cannot speak. '
            'This is an emergency.',
    };
  }
}
