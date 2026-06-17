import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Certified ASL gloss mappings from ASL-LEX 2.0 + ASL Sign Bank cross-refs.
///
/// Data built from [ASL-LEX 2.0](https://asl-lex.org/download.html) SignData
/// (CC BY-NC 4.0). Regenerate via `python3 scripts/build_asl_sign_lexicon.py`.
///
/// Cite: Caselli et al. (2017); Sevcikova Sehyr et al. (2021). ASL Sign Bank:
/// https://aslsignbank.haskins.yale.edu/
class AslSignEntry {
  const AslSignEntry({required this.gloss, required this.id});

  final String gloss;
  final String id;
}

abstract final class AslSignLexicon {
  static const _assetPath = 'assets/lexicon/asl_sign_lexicon.txt';

  static Map<String, AslSignEntry>? _entries;

  static Future<void> load() async {
    if (_entries != null) {
      return;
    }
    try {
      final text = await rootBundle.loadString(_assetPath);
      final map = <String, AslSignEntry>{};
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final parts = trimmed.split('|');
        if (parts.length < 3) {
          continue;
        }
        final word = parts[0].trim().toLowerCase();
        final gloss = parts[1].trim();
        final id = parts[2].trim();
        if (word.isEmpty || gloss.isEmpty || id.isEmpty) {
          continue;
        }
        map[word] = AslSignEntry(gloss: gloss, id: id);
      }
      _entries = map;
    } on Object {
      _entries = {};
    }
  }

  @visibleForTesting
  static void useEntriesForTest(Map<String, AslSignEntry> entries) {
    _entries = entries;
  }

  @visibleForTesting
  static void resetForTest() {
    _entries = null;
  }

  static int get loadedEntryCount => _entries?.length ?? 0;

  static AslSignEntry? lookup(String normalized) {
    final word = normalized.trim().toLowerCase();
    if (word.isEmpty) {
      return null;
    }
    return _entries?[word];
  }

  static bool contains(String normalized) => lookup(normalized) != null;
}
