import 'asl_nmm_markers.dart';
import 'isl_nmm_markers.dart';
import 'sign_grammar_engine.dart';
import 'sign_language_system.dart';
import 'sign_lexicon_builder.dart';
import 'sign_token.dart';
import 'asl_grammar_rules.dart';
import 'spoken_text_prep.dart';

/// Lexicon mapping spoken words to ASL / ISL gloss tokens and avatar pose ids.
abstract final class SignLanguageCatalog {
  static const _thinking = SignToken.thinking;

  static List<SignToken> sequenceFor(String transcript, String languageCode) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final fullEndsWithQuestion = trimmed.endsWith('?');

    final clauses = trimmed
        .split(RegExp(r'[.!?]+'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (clauses.isEmpty) {
      return const [];
    }

    final tokens = <SignToken>[];
    for (var i = 0; i < clauses.length; i++) {
      final clause = clauses[i];
      final clauseIsQuestion =
          _clauseIsQuestion(clause) ||
          (fullEndsWithQuestion && i == clauses.length - 1);
      tokens.addAll(
        _sequenceForClause(
          clause,
          languageCode,
          clauseIsQuestion: clauseIsQuestion,
        ),
      );
    }
    return tokens;
  }

  static bool _clauseIsQuestion(String clause) {
    final trimmed = clause.trim();
    if (trimmed.endsWith('?')) {
      return true;
    }
    if (SpokenTextPrep.inferWhQuestion(clause)) {
      return true;
    }
    return SpokenTextPrep.inferYesNoQuestion(clause);
  }

  static List<SignToken> _sequenceForClause(
    String transcript,
    String languageCode, {
    bool clauseIsQuestion = false,
  }) {
    final system = SignLanguageSystem.forSpokenLanguage(languageCode);
    final prepared = SpokenTextPrep.normalizeForGloss(transcript, languageCode);
    final rawWords = splitWords(prepared);
    if (rawWords.isEmpty) {
      return const [];
    }

    final isWhQuestion = _isWhQuestion(rawWords);
    final isYesNoQuestion = clauseIsQuestion && !isWhQuestion;

    final words = SignGrammarEngine.applyRules(
      rawWords,
      system,
      isWhQuestion: isWhQuestion,
      isYesNoQuestion: isYesNoQuestion,
      clauseIsQuestion: clauseIsQuestion,
    );
    if (words.isEmpty) {
      return const [];
    }

    final fingerspellIndices = system == SignLanguageSystem.asl ||
            system == SignLanguageSystem.isl
        ? SignGrammarEngine.fingerspellWordIndices(words)
        : const <int>{};

    final tokens = <SignToken>[];
    for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
      final word = words[wordIndex];
      final normalized = normalize(word);
      if (normalized.isEmpty) {
        continue;
      }

      if (AslNmmMarkers.isMarker(word) || IslNmmMarkers.isMarker(word)) {
        tokens.add(AslNmmMarkers.token(word, system));
        continue;
      }

      if (fingerspellIndices.contains(wordIndex)) {
        final spelled = SignLexiconBuilder.fingerspell(
          normalized,
          system,
          fsLabel: true,
        );
        if (spelled.isEmpty) {
          _addToken(tokens, _fallbackToken(normalized, system));
          continue;
        }
        tokens.addAll(spelled);
        continue;
      }

      final token = SignLexiconBuilder.resolve(normalized, system);
      if (token == null) {
        final spelled = SignLexiconBuilder.fingerspell(normalized, system);
        if (spelled.isNotEmpty) {
          tokens.addAll(spelled);
          continue;
        }
        _addToken(tokens, _fallbackToken(normalized, system));
        continue;
      }
      _addToken(tokens, token);
    }

    if (system == SignLanguageSystem.isl) {
      return _applyIslConversationalGlossLabels(
        _stripIslChipNmm(tokens),
        clauseIsQuestion: clauseIsQuestion,
        isWhQuestion: isWhQuestion,
        isYesNoQuestion: isYesNoQuestion,
      );
    }
    return tokens;
  }

  static List<SignToken> _stripIslChipNmm(List<SignToken> tokens) {
    return tokens
        .where(
          (t) =>
              t.gloss == '[y/n-q]' ||
              (!t.gloss.startsWith('[') && !t.gloss.endsWith(']')),
        )
        .toList();
  }

  static List<SignToken> _applyIslConversationalGlossLabels(
    List<SignToken> tokens, {
    required bool clauseIsQuestion,
    required bool isWhQuestion,
    required bool isYesNoQuestion,
  }) {
    if (!clauseIsQuestion || tokens.isEmpty) {
      return _applyIslImperativeExclamation(tokens);
    }
    final out = tokens
        .where((t) => t.gloss != '[wh-q]')
        .map((t) => t)
        .toList();
    if (out.isEmpty) {
      return out;
    }
    if (isYesNoQuestion) {
      final last = out.last;
      if (!last.gloss.endsWith('?') && last.gloss != 'NEED') {
        out[out.length - 1] = last.copyWith(gloss: '${last.gloss}?');
      }
      return out;
    }
    if (isWhQuestion) {
      for (var i = out.length - 1; i >= 0; i--) {
        final upper = out[i].gloss.toUpperCase();
        if (AslGrammarRules.questionWords.contains(out[i].gloss.toLowerCase()) ||
            upper == 'HOW-MANY' ||
            upper == 'HOW-MUCH') {
          if (!out[i].gloss.endsWith('?')) {
            out[i] = out[i].copyWith(gloss: '${out[i].gloss}?');
          }
          break;
        }
      }
    }
    return _applyIslImperativeExclamation(out);
  }

  /// AMBULANCE CALL QUICK! — curriculum imperatives use trailing `!`.
  static List<SignToken> _applyIslImperativeExclamation(List<SignToken> tokens) {
    if (tokens.isEmpty) {
      return tokens;
    }
    final last = tokens.last;
    if (last.gloss.endsWith('!') || last.gloss.endsWith('?')) {
      return tokens;
    }
    if (last.gloss == 'QUICK' || last.gloss == 'CALL') {
      final out = List<SignToken>.from(tokens);
      out[out.length - 1] = last.copyWith(gloss: '${last.gloss}!');
      return out;
    }
    return tokens;
  }

  static void _addToken(List<SignToken> tokens, SignToken token) {
    if (tokens.isEmpty || tokens.last.id != token.id) {
      tokens.add(token);
    }
  }

  static SignToken activeToken(String transcript, String languageCode) {
    final sequence = sequenceFor(transcript, languageCode);
    if (sequence.isEmpty) {
      final system = SignLanguageSystem.forSpokenLanguage(languageCode);
      return SignToken(
        id: _thinking.id,
        gloss: _thinking.gloss,
        system: system,
      );
    }
    return sequence.last;
  }

  static SignToken tokenForGloss(String gloss, SignLanguageSystem system) {
    final resolved = SignLexiconBuilder.tokenForGloss(gloss, system);
    if (resolved != null) {
      return resolved;
    }
    return _fallbackToken(gloss.trim().toLowerCase(), system);
  }

  static String glossLabel(SignToken token) => token.gloss;

  static SignToken _fallbackToken(
    String normalized,
    SignLanguageSystem system,
  ) {
    if (normalized.isEmpty) {
      return SignToken(
        id: _thinking.id,
        gloss: _thinking.gloss,
        system: system,
      );
    }
    final gloss = normalized.toUpperCase();
    return SignToken(id: normalized, gloss: gloss, system: system);
  }

  static const _hyphenCompounds = {
    'check-in',
    'check-ins',
    'eco-friendly',
    'sci-fi',
    'ride-share',
    'ride-sharing',
    'km/l',
    'not-can',
    'pass-me',
    'wake-up',
    'tear-open',
    'too-much',
    'take-away',
    'two-pieces',
    'jump-over',
    'write-wrong',
    'three-times',
    'high-speed',
    'oat-milk',
    'credit-card',
    'cold-brew',
    'gluten-free',
    'new-york',
    'new-delhi',
    'excuse-me',
    'text-me',
    'go-there',
    'help-me',
    'for-me',
    'call-me',
    'send-back',
    'move-here',
    'co-worker',
    'all-night',
    'all-day',
    'look-at',
    'two-times',
    'clean-all',
    'cover-all',
    'knock-over',
    'cool-down',
    'clap-loud',
    'try-on',
    'fly-here',
    'leave-behind',
    'locked-out',
    'not-allow',
    'next-to-you',
    'snow-storm',
    'wi-fi',
    'give-you',
    'give-me',
    'tell-you',
    'tell-me',
    'two-days',
    'five-years',
    'three-weeks-ago',
    'years-old',
    'book-on',
    'point-there',
    'point-there-plural',
    '3-day',
    'one-day',
    'two-day',
    'three-day',
    'how-many',
    'how-much',
    'deep/far',
    'will-be',
    '10-o\'clock',
  };

  static List<String> splitWords(String transcript) {
    final tokens = <String>[];
    for (final word in transcript.trim().split(RegExp(r'\s+'))) {
      if (word.isEmpty) {
        continue;
      }
      final lower = word.toLowerCase().replaceAll(RegExp(r"^[\p{P}\p{S}']+|[\p{P}\p{S}']+$", unicode: true), '');
      if (lower.startsWith('fs-') || lower.contains('/')) {
        tokens.add(word);
        continue;
      }
      if (RegExp(r'^\d{1,2}-o.clock', caseSensitive: false).hasMatch(lower)) {
        tokens.add(word);
        continue;
      }
      if (_hyphenCompounds.contains(lower)) {
        tokens.add(word);
        continue;
      }
      for (final part in word.split(RegExp(r'-+'))) {
        if (part.isNotEmpty) {
          tokens.add(part);
        }
      }
    }
    return tokens;
  }

  static String normalize(String word) {
    final trimmed = word.trim();
    final stripped = trimmed.replaceAll(
      RegExp(r"^[\p{P}\p{S}']+|[\p{P}\p{S}']+$", unicode: true),
      '',
    );
    var lower = stripped.toLowerCase();
    // Currency symbols: ₹2000 → 2000
    lower = lower.replaceAll(RegExp(r'[₹$€£]'), '');
    if (lower.endsWith('%') && lower.length > 1) {
      lower = lower.substring(0, lower.length - 1);
    }
  // Possessive 's: cat's → cat (HandsSpeak: possession shown in context).
    if (lower.length > 3 && (lower.endsWith("'s") || lower.endsWith('\u2019s'))) {
      lower = lower.substring(0, lower.length - 2);
    }
    return lower;
  }

  static bool _isWhQuestion(List<String> rawWords) {
    for (final word in rawWords) {
      final n = normalize(word);
      if (AslGrammarRules.questionWords.contains(n)) {
        return true;
      }
      if (n == 'how-much' || n == 'how-many') {
        return true;
      }
    }
    return false;
  }

}
