/// Computes the new spoken caption text that still needs glossing.
abstract final class GlossCaptionDelta {
  /// Returns the suffix of [fullCaption] that extends beyond [glossedPrefix],
  /// or `null` when there is nothing new to gloss.
  static String? compute({
    required String fullCaption,
    required String glossedPrefix,
  }) {
    final full = fullCaption.trim();
    if (full.isEmpty) {
      return null;
    }

    final prior = glossedPrefix.trim();
    if (prior.isEmpty) {
      return full;
    }
    if (full == prior) {
      return null;
    }

    if (full.startsWith(prior)) {
      final suffix = full.substring(prior.length).trimLeft();
      return suffix.isEmpty ? null : suffix;
    }

    return _wordSuffixDelta(prior, full);
  }

  static String? _wordSuffixDelta(String prior, String full) {
    final priorWords = _words(prior);
    final fullWords = _words(full);
    if (fullWords.isEmpty) {
      return null;
    }

    var common = 0;
    while (common < priorWords.length &&
        common < fullWords.length &&
        priorWords[common] == fullWords[common]) {
      common++;
    }

    if (common >= fullWords.length) {
      return null;
    }

    return fullWords.sublist(common).join(' ');
  }

  static List<String> _words(String text) =>
      text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
}
