import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'phrase_speech_service.dart';
import 'tts_locale_resolver.dart';

typedef AudioSessionRelease = Future<void> Function();

final class LocalPhraseSpeechService implements PhraseSpeechService {
  LocalPhraseSpeechService({
    FlutterTts? tts,
    AudioSessionRelease? releaseAudioSession,
  }) : _ttsOverride = tts,
       _releaseAudioSession = releaseAudioSession ?? (() async {});

  final FlutterTts? _ttsOverride;
  final AudioSessionRelease _releaseAudioSession;
  FlutterTts? _tts;
  bool _initialized = false;
  bool _iosAudioConfigured = false;

  FlutterTts get _engine => _tts ??= _ttsOverride ?? FlutterTts();

  Future<void> _configureIosPlaybackSession() async {
    if (_iosAudioConfigured ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await _engine.setSharedInstance(true);
    await _engine.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ], IosTextToSpeechAudioMode.spokenAudio);
    _iosAudioConfigured = true;
  }

  Future<void> _ensureInitialized(String languageCode) async {
    await _configureIosPlaybackSession();

    if (!_initialized) {
      await _engine.setSpeechRate(0.48);
      await _engine.setVolume(1);
      await _engine.setPitch(1);
      await _engine.awaitSpeakCompletion(true);
      _initialized = true;
    }

    await _setLanguage(languageCode);
  }

  Future<void> _setLanguage(String languageCode) async {
    final locale =
        await TtsLocaleResolver.resolve(_engine, languageCode) ??
        TtsLocaleResolver.preferredLocale(languageCode);
    if (locale == null) {
      return;
    }
    try {
      await _engine.setLanguage(locale);
    } on Object {
      final fallback = TtsLocaleResolver.preferredLocale('ENG');
      if (fallback != null) {
        await _engine.setLanguage(fallback);
      }
    }
  }

  @override
  Future<void> speak(String text, String languageCode) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    // Release STT / mic capture so iOS can route audio to the speaker.
    await _releaseAudioSession();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
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
