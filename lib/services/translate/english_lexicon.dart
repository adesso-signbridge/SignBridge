import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Full English dictionary word set for gloss lookup (no letter-by-letter spelling).
///
/// Sourced from the system English word list (~235k entries). Oxford/OED-scale
/// coverage for everyday and technical English; loaded once at app startup.
abstract final class EnglishLexicon {
  static const _assetPath = 'assets/lexicon/english_dictionary.txt';

  static Set<String>? _words;

  static Future<void> load() async {
    if (_words != null) {
      return;
    }
    try {
      final text = await rootBundle.loadString(_assetPath);
      _words = text
          .split('\n')
          .map((line) => line.trim().toLowerCase())
          .where((line) => line.isNotEmpty)
          .toSet();
    } on Object {
      _words = {};
    }
  }

  @visibleForTesting
  static void useWordsForTest(Set<String> words) {
    _words = words;
  }

  @visibleForTesting
  static void resetForTest() {
    _words = null;
  }

  static int get loadedWordCount => _words?.length ?? 0;

  /// True when the word is in the dictionary or looks like a Latin token.
  static bool contains(String normalized) {
    final word = normalized.trim().toLowerCase();
    if (word.isEmpty) {
      return false;
    }
    final words = _words;
    if (words != null) {
      return words.contains(word);
    }
    return _looksLatin(word);
  }

  static bool _looksLatin(String word) {
    return RegExp(r'^[a-z0-9]+$').hasMatch(word);
  }
}
