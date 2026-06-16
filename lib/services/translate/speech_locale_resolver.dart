import 'package:speech_to_text/speech_to_text.dart';

/// Picks a speech-recognition locale available on the device.
abstract final class SpeechLocaleResolver {
  static Future<String?> resolve(
    SpeechToText speech,
    String languageCode,
  ) async {
    final locales = await speech.locales();
    if (locales.isEmpty) {
      return null;
    }

    final candidates = _candidatesFor(languageCode);
    for (final candidate in candidates) {
      final match = _findLocale(locales, candidate);
      if (match != null) {
        return match.localeId;
      }
    }

    final prefix = _languagePrefix(languageCode);
    if (prefix != null) {
      final prefixMatch = locales.cast<LocaleName?>().firstWhere(
        (locale) => locale!.localeId.toLowerCase().startsWith(prefix),
        orElse: () => null,
      );
      if (prefixMatch != null) {
        return prefixMatch.localeId;
      }
    }

    // Don't fall back to an arbitrary locale (some devices return e.g. zh-CN as
    // the first supported locale). Returning null lets the recognizer choose the
    // device default instead.
    return null;
  }

  static List<String> _candidatesFor(String languageCode) {
    return switch (languageCode) {
      'ENG' => const [
        'en_US',
        'en-US',
        'en_IN',
        'en-IN',
        'en_GB',
        'en-GB',
        'en_AU',
        'en-AU',
      ],
      'HI' => const ['hi_IN', 'hi-IN', 'hi'],
      'TA' => const ['ta_IN', 'ta-IN', 'ta'],
      'ML' => const ['ml_IN', 'ml-IN', 'ml'],
      _ => const ['en_US', 'en-US'],
    };
  }

  static String? _languagePrefix(String languageCode) {
    return switch (languageCode) {
      'ENG' => 'en',
      'HI' => 'hi',
      'TA' => 'ta',
      'ML' => 'ml',
      _ => null,
    };
  }

  static LocaleName? _findLocale(List<LocaleName> locales, String candidate) {
    final normalized = candidate.replaceAll('-', '_').toLowerCase();
    for (final locale in locales) {
      if (locale.localeId.replaceAll('-', '_').toLowerCase() == normalized) {
        return locale;
      }
    }
    return null;
  }
}
