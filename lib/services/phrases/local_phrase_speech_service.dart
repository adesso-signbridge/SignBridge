import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'phrase_speech_service.dart';

final class LocalPhraseSpeechService implements PhraseSpeechService {
  LocalPhraseSpeechService({FlutterTts? tts}) : _ttsOverride = tts;

  final FlutterTts? _ttsOverride;
  FlutterTts? _tts;
  bool _initialized = false;

  FlutterTts get _engine => _tts ??= _ttsOverride ?? FlutterTts();

  static const _localeByLanguage = <String, String>{
    'ENG': 'en-US',
    'HI': 'hi-IN',
    'TA': 'ta-IN',
    'ML': 'ml-IN',
  };

  Future<void> _ensureInitialized(String languageCode) async {
    if (!_initialized) {
      await _engine.setSpeechRate(0.48);
      await _engine.setVolume(1);
      await _engine.setPitch(1);
      await _engine.awaitSpeakCompletion(true);
      _initialized = true;
    }

    final locale = _localeByLanguage[languageCode] ?? 'en-US';
    try {
      await _engine.setLanguage(locale);
    } on Object {
      if (kDebugMode) {
        await _engine.setLanguage('en-US');
      }
    }
  }

  @override
  Future<void> speak(String text, String languageCode) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _ensureInitialized(languageCode);
    await _engine.stop();
    await _engine.speak(trimmed);
  }

  @override
  Future<void> stop() async {
    if (_tts != null) {
      await _tts!.stop();
    }
  }
}
