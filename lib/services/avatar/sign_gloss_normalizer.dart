/// Normalizes gloss labels and sign ids for Hugging Face asset lookup.
abstract final class SignGlossNormalizer {
  static String normalizeKey(String raw) {
    return raw
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll('_', '-')
        .replaceAll(RegExp(r'[^A-Z0-9-]'), '')
        .toLowerCase()
        .replaceAll('-', '_');
  }

  /// Maps common gloss variants to the canonical manifest key when present.
  static String canonicalKey(String raw) {
    final normalized = normalizeKey(raw);
    return _canonicalAliases[normalized] ?? normalized;
  }

  static List<String> lookupKeys({
    required String signId,
    required String gloss,
  }) {
    final seen = <String>{};
    final keys = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        return;
      }
      keys.add(trimmed);
    }

    add(signId);
    add(normalizeKey(signId));
    add(canonicalKey(signId));

    add(gloss);
    add(normalizeKey(gloss));
    add(canonicalKey(gloss));

    return keys;
  }

  static const _canonicalAliases = <String, String>{
    'hi': 'hello',
    'hey': 'hello',
    'thanks': 'thank_you',
    'thank': 'thank_you',
    'thank_you': 'thank_you',
    'excuse_me': 'excuse_me',
    'pass_me': 'pass_me',
    'wake_up': 'wake_up',
    'cannot': 'cannot',
    'can_not': 'cannot',
    'dont': 'no',
    'do_not': 'no',
    'not': 'no',
    'pls': 'please',
    'okay': 'good',
    'ok': 'good',
    'fine': 'good',
  };
}
