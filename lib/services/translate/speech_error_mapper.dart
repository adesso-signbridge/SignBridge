/// Maps [speech_to_text] error codes to short user-facing messages.
abstract final class SpeechErrorMapper {
  static String userMessage(String errorMsg) {
    return switch (errorMsg) {
      'error_permission' =>
        'Speech recognition was blocked. Allow microphone for SignBridge '
            'and Google, then set Voice input to Speech services by Google.',
      'error_network' ||
      'error_network_timeout' ||
      'error_server_disconnected' =>
        'Speech recognition needs an internet connection.',
      'error_language_not_supported' || 'error_language_unavailable' =>
        'Speech language is not available. In Settings, set Voice input to '
            '"Speech services by Google", then try again.',
      'error_busy' || 'error_recognizer_busy' =>
        'Speech recognition is busy. Wait a moment and try again.',
      'error_no_match' || 'error_speech_timeout' => 'No speech detected.',
      'error_audio_error' =>
        'Microphone audio failed. Check that no other app is using the mic.',
      _ => 'Could not recognize speech. Please try again.',
    };
  }
}
