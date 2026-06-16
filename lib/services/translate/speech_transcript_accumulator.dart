import 'dart:math' as math;

/// Merges partial and final speech-recognition segments into one live caption.
///
/// Follows the same model as [speech_to_text] samples and continuous-listen apps:
/// - **Committed lines** — finalized phrases appended when a result is final or
///   the OS ends a listen chunk (`done`).
/// - **Hypothesis** — current [SpeechRecognitionResult.recognizedWords] for the
///   active listen session; updated directly on each partial (the plugin replaces
///   the string as the recognizer refines).
///
/// This matches [accessibility_platform]'s caption list (one entry per segment)
/// while staying on device STT instead of Whisper sliding windows.
final class SpeechTranscriptAccumulator {
  final List<String> _lines = [];
  String _hypothesis = '';

  String get committed => _lines.join(' ');

  String get live {
    final base = committed;
    final hypothesis = _hypothesis.trim();
    if (hypothesis.isEmpty) {
      return base;
    }
    if (base.isEmpty) {
      return hypothesis;
    }
    return '$base $hypothesis';
  }

  void reset() {
    _lines.clear();
    _hypothesis = '';
  }

  /// Called when the OS ends a listen chunk and a new one will start.
  void onRecognizerReset() {
    finalizeOpenDraft();
  }

  /// Commits the open hypothesis before pause or stop.
  void finalizeOpenDraft() {
    _commit(_hypothesis);
    _hypothesis = '';
  }

  /// Partial result for the current listen session.
  void applyPartial(String partial) {
    final words = partial.trim();
    if (words.isEmpty) {
      return;
    }

    final base = committed;
    if (base.isNotEmpty) {
      if (base == words || base.endsWith(words) || base.startsWith(words)) {
        return;
      }
      final anchor = base.trimRight();
      if (words.startsWith(base) || words.startsWith(anchor)) {
        final offset = words.startsWith(base) ? base.length : anchor.length;
        _hypothesis = words.substring(offset).trimLeft();
        return;
      }
      if (_lines.isNotEmpty) {
        final lastLine = _lines.last.trim();
        if (lastLine.isNotEmpty && words.startsWith(lastLine)) {
          _hypothesis = words.substring(lastLine.length).trimLeft();
          if (_hypothesis.isEmpty) {
            return;
          }
          return;
        }
      }
    }

    if (_hypothesis.startsWith(words) && words.length < _hypothesis.length) {
      return;
    }
    _hypothesis = words;
  }

  /// Final result for the current listen session.
  void applyFinal(String segment) {
    final text = segment.trim();
    if (text.isEmpty) {
      return;
    }
    _hypothesis = '';
    _commit(text);
  }

  void _commit(String text) {
    final phrase = text.trim();
    if (phrase.isEmpty) {
      return;
    }

    final base = committed;
    if (base.isEmpty) {
      _lines.add(phrase);
      return;
    }
    if (phrase.startsWith(base)) {
      final tail = phrase.substring(base.length).trimLeft();
      if (tail.isNotEmpty && !_isDuplicateTail(base, tail)) {
        _lines.add(tail);
      }
      return;
    }
    if (_isDuplicateTail(base, phrase)) {
      return;
    }
    _lines.add(phrase);
  }

  /// Keeps the longest caption for a listen session — never shortens on STT resets.
  static String mergeSessionCaption(String previous, String incoming) {
    final prev = previous.trim();
    final next = incoming.trim();
    if (next.isEmpty) {
      return prev;
    }
    if (prev.isEmpty) {
      return next;
    }
    if (next == prev) {
      return prev;
    }
    if (next.startsWith(prev)) {
      return next;
    }
    if (prev.startsWith(next)) {
      return prev;
    }
    if (prev.endsWith(next)) {
      return prev;
    }
    final overlapWords = _sharedWordOverlapCount(prev, next);
    if (overlapWords != null && overlapWords > 0) {
      final rightWords = next.split(RegExp(r'\s+'));
      final remainder = rightWords.sublist(overlapWords).join(' ');
      if (remainder.isEmpty) {
        return prev;
      }
      return '$prev $remainder';
    }
    return '$prev $next';
  }

  static int? _sharedWordOverlapCount(String left, String right) {
    final leftWords = left.split(RegExp(r'\s+'));
    final rightWords = right.split(RegExp(r'\s+'));
    final max = math.min(leftWords.length, rightWords.length);
    for (var size = max; size > 0; size--) {
      final suffix = leftWords.sublist(leftWords.length - size);
      final prefix = rightWords.sublist(0, size);
      if (_wordListsEqual(suffix, prefix)) {
        return size;
      }
    }
    return null;
  }

  static bool _wordListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  static bool _isDuplicateTail(String committed, String segment) {
    final left = committed.trimRight();
    final right = segment.trim();
    if (right.isEmpty) {
      return true;
    }
    if (left == right || left.endsWith(right)) {
      return true;
    }
    return left.endsWith(' $right');
  }
}
