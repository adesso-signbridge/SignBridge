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
  SpeechTranscriptAccumulator({this.iosRollingRefinement = false});

  /// When true, applies iOS-specific dedupe for rolling phrase refinements
  /// ("Hello one" -> "Hello 12" -> "Hello 123...") and chunk replay stripping.
  final bool iosRollingRefinement;

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

  /// Current utterance for live signing gloss — not the full session history.
  String get currentPhrase {
    final open = _hypothesis.trim();
    if (open.isNotEmpty) {
      return open;
    }
    if (_lines.isEmpty) {
      return '';
    }
    return _lines.last.trim();
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
        final prefix = words.startsWith(base) ? base : anchor;
        final tail = _tailAfterPrefix(prefix, words);
        if (tail == null) {
          return;
        }
        _hypothesis = tail;
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
        if (iosRollingRefinement && _replaceLastLineIfRefinement(words)) {
          return;
        }
      }
    }

    if (iosRollingRefinement &&
        _hypothesis.isNotEmpty &&
        _isSameUtteranceRefinement(_hypothesis, words)) {
      if (!_hypothesis.startsWith(words)) {
        _hypothesis = words;
      }
      return;
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
    if (iosRollingRefinement && _replaceLastLineIfRefinement(text)) {
      return;
    }
    _commit(text);
  }

  bool _replaceLastLineIfRefinement(String words) {
    if (_lines.isEmpty) {
      return false;
    }
    final last = _lines.last.trim();
    if (!_isSameUtteranceRefinement(last, words)) {
      return false;
    }
    _lines[_lines.length - 1] = words.length >= last.length ? words : last;
    return true;
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
      final tail = _tailAfterPrefix(base, phrase);
      if (tail != null) {
        _lines.add(tail);
      }
      return;
    }
    if (_isDuplicateTail(base, phrase)) {
      return;
    }
    if (iosRollingRefinement && _lines.isNotEmpty) {
      final last = _lines.last.trim();
      if (_isSameUtteranceRefinement(last, phrase)) {
        _lines[_lines.length - 1] = phrase.length >= last.length
            ? phrase
            : last;
        return;
      }
    }
    _lines.add(phrase);
  }

  /// iOS often emits several finals for the same rolling phrase (e.g. "Hello one"
  /// then "Hello 12" then "Hello 123 Mike test"). Treat those as refinements.
  static bool _isSameUtteranceRefinement(String previous, String next) {
    final prev = previous.trim();
    final nextText = next.trim();
    if (prev.isEmpty || nextText.isEmpty) {
      return false;
    }
    if (nextText == prev) {
      return true;
    }
    if (nextText.startsWith(prev)) {
      return true;
    }
    if (prev.startsWith(nextText)) {
      return false;
    }

    final prevWords = prev.split(RegExp(r'\s+'));
    final nextWords = nextText.split(RegExp(r'\s+'));
    if (prevWords.isEmpty || nextWords.isEmpty) {
      return false;
    }
    if (prevWords.first.toLowerCase() != nextWords.first.toLowerCase()) {
      return false;
    }

    var sharedPrefixWords = 0;
    final limit = math.min(prevWords.length, nextWords.length);
    for (var i = 0; i < limit; i++) {
      if (prevWords[i].toLowerCase() != nextWords[i].toLowerCase()) {
        break;
      }
      sharedPrefixWords++;
    }
    if (sharedPrefixWords == 0) {
      return false;
    }

    // iOS keeps refining the same rolling phrase; length may shrink briefly
    // ("Hello one" -> "Hello 12") before growing again.
    return true;
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
      var suffix = next.substring(prev.length).trimLeft();
      if (suffix.isEmpty) {
        return prev;
      }
      suffix = _stripReplayedPrefix(prev, suffix);
      if (suffix.isEmpty || _isDuplicateTail(prev, suffix)) {
        return prev;
      }
      return '$prev $suffix';
    }
    if (prev.startsWith(next)) {
      return prev;
    }
    if (prev.endsWith(next)) {
      return prev;
    }
    if (_isDuplicateTail(prev, next)) {
      return prev;
    }
    if (next.length > prev.length && next.contains(prev)) {
      final replayAt = next.indexOf(prev);
      if (replayAt > 0) {
        final prefix = next.substring(0, replayAt).trimRight();
        var suffix = next.substring(replayAt + prev.length).trimLeft();
        suffix = _stripReplayedPrefix(prev, suffix);
        if (suffix.isEmpty) {
          return prefix.isEmpty ? prev : '$prefix $prev'.trim();
        }
        if (prefix.isEmpty) {
          return '$prev $suffix';
        }
        return '$prefix $prev $suffix';
      }
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

  /// Extracts only the new words after [prefix], optionally stripping iOS replay.
  String? _tailAfterPrefix(String prefix, String words) {
    final anchor = prefix.trim();
    final full = words.trim();
    if (!full.startsWith(anchor)) {
      return null;
    }
    var tail = full.substring(anchor.length).trimLeft();
    if (tail.isEmpty) {
      return null;
    }
    if (iosRollingRefinement) {
      tail = _stripReplayedPrefix(anchor, tail);
    }
    if (tail.isEmpty || _isDuplicateTail(anchor, tail)) {
      return null;
    }
    return tail;
  }

  /// iOS often replays the previous chunk inside the next partial/final.
  static String _stripReplayedPrefix(String anchor, String text) {
    var current = text.trim();
    final replay = anchor.trim();
    if (replay.isEmpty) {
      return current;
    }
    while (current.startsWith(replay)) {
      current = current.substring(replay.length).trimLeft();
    }
    return current;
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
