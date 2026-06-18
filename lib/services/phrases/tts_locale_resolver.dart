import 'package:flutter_tts/flutter_tts.dart';

/// Picks a TTS locale available on the device for [languageCode].
abstract final class TtsLocaleResolver {
  static Future<String?> resolve(
    FlutterTts engine,
    String languageCode,
  ) async {
    final languages = await engine.getLanguages;
    if (languages is! List || languages.isEmpty) {
      return _preferredLocale(languageCode);
    }

    final available = languages.map((entry) => '$entry').toList();
    for (final candidate in _candidatesFor(languageCode)) {
      final match = _findLocale(available, candidate);
      if (match != null) {
        return match;
      }
    }

    final prefix = _languagePrefix(languageCode);
    if (prefix != null) {
      for (final locale in available) {
        if (locale.toLowerCase().replaceAll('-', '_').startsWith(prefix)) {
          return locale;
        }
      }
    }

    return _preferredLocale(languageCode);
  }

  static String? preferredLocale(String languageCode) {
    return _preferredLocale(languageCode);
  }

  static String? _preferredLocale(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'ENG' => 'en-US',
      'HI' => 'hi-IN',
      'TA' => 'ta-IN',
      'ML' => 'ml-IN',
      _ => 'en-US',
    };
  }

  static List<String> _candidatesFor(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'ENG' => const [
        'en-US',
        'en_US',
        'en-IN',
        'en_IN',
        'en-GB',
        'en_GB',
      ],
      'HI' => const ['hi-IN', 'hi_IN', 'hi-in', 'hi'],
      'TA' => const ['ta-IN', 'ta_IN', 'ta-in', 'ta'],
      'ML' => const ['ml-IN', 'ml_IN', 'ml-in', 'ml'],
      _ => const ['en-US', 'en_US'],
    };
  }

  static String? _languagePrefix(String languageCode) {
    return switch (languageCode.trim().toUpperCase()) {
      'ENG' => 'en',
      'HI' => 'hi',
      'TA' => 'ta',
      'ML' => 'ml',
      _ => null,
    };
  }

  static String? _findLocale(List<String> locales, String candidate) {
    final normalized = candidate.replaceAll('-', '_').toLowerCase();
    for (final locale in locales) {
      if (locale.replaceAll('-', '_').toLowerCase() == normalized) {
        return locale;
      }
    }
    return null;
  }
}
