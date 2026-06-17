import 'english_lexicon.dart';
import 'asl_core_lexicon.dart';
import 'asl_sign_lexicon.dart';
import 'asl_grammar_rules.dart';
import 'sign_language_system.dart';
import 'sign_token.dart';

/// Resolves spoken words to sign tokens using dictionary + ASL gloss overrides.
abstract final class SignLexiconBuilder {
  static const _glossOverrides = AslCoreLexicon.glossOverrides;

  static const _idOverrides = AslCoreLexicon.idOverrides;

  static const _grammarMarkers = {
    ...AslGrammarRules.grammarMarkers,
    'ix',
    'ix-a',
    'ix-b',
    'ix-c',
    'ix-d',
    'me',
    'my',
    'your',
    'we',
    'they',
    'our',
    'their',
    'us',
    'them',
    'this',
    'that',
    'name',
  };

  static final _islRegional = _regionalIslEntries();

  static final _letterPattern = RegExp(r'[a-zA-Z]');

  static final _locativeCompound = RegExp(
    r'^[\w]+-(on-top|on|under|in|beside)$',
  );

  static final _clockTimePattern = RegExp(r'^\d{1,2}:\d{2}$');
  static final _digitsPattern = RegExp(r'^\d+$');
  static final _percentPattern = RegExp(r'^(\d+)%$');

  static SignToken? resolve(String normalized, SignLanguageSystem system) {
    if (normalized.isEmpty) {
      return null;
    }

    if (RegExp(r'^\d{1,2}-o.clock', caseSensitive: false).hasMatch(normalized)) {
      return SignToken(
        id: normalized,
        gloss: AslCoreLexicon.corpusGlosses[normalized] ??
            normalized.toUpperCase(),
        system: system,
      );
    }

    final clock = _clockTimePattern.matchAsPrefix(normalized);
    if (clock != null) {
      return SignToken(
        id: 'time_$normalized',
        gloss: normalized,
        system: system,
      );
    }

    if (_digitsPattern.hasMatch(normalized)) {
      return SignToken(
        id: 'num_$normalized',
        gloss: normalized,
        system: system,
      );
    }

    final percent = _percentPattern.firstMatch(normalized);
    if (percent != null) {
      final digits = percent.group(1)!;
      return SignToken(
        id: 'num_$digits',
        gloss: digits,
        system: system,
      );
    }

    for (final form in _lookupForms(normalized)) {
      final token = _resolveForm(form, system);
      if (token != null) {
        return token;
      }
    }
    return null;
  }

  /// Try plural / conjugated forms before fingerspelling (ROUTINE from routines).
  static List<String> _lookupForms(String normalized) {
    final forms = <String>[normalized];
    if (normalized.endsWith('ies') && normalized.length > 4) {
      forms.add('${normalized.substring(0, normalized.length - 3)}y');
    }
    if (normalized.endsWith('ates') && normalized.length > 6) {
      forms.add(normalized.substring(0, normalized.length - 1));
    }
    if (normalized.endsWith('izes') && normalized.length > 6) {
      forms.add(normalized.substring(0, normalized.length - 1));
    }
    if (normalized.endsWith('ifies') && normalized.length > 7) {
      forms.add('${normalized.substring(0, normalized.length - 3)}y');
    }
    if (_shouldStripEsPlural(normalized)) {
      forms.add(normalized.substring(0, normalized.length - 2));
    }
    if (normalized.endsWith('uses') && normalized.length > 5) {
      forms.add(normalized.substring(0, normalized.length - 2));
    }
    if (normalized.endsWith('es') && normalized.length > 3) {
      final stem = normalized.substring(0, normalized.length - 2);
      forms.add('${stem}e');
    }
    if (normalized.endsWith('s') &&
        normalized.length > 4 &&
        !normalized.endsWith('ss') &&
        !normalized.endsWith('us')) {
      forms.add(normalized.substring(0, normalized.length - 1));
    }
    if (normalized.endsWith('iest') && normalized.length > 5) {
      forms.add('${normalized.substring(0, normalized.length - 4)}y');
    }
    if (normalized.endsWith('est') && normalized.length > 4) {
      final base = normalized.substring(0, normalized.length - 3);
      forms.add(base);
      forms.add('${base}e');
    }
    final ingStem = _stemFromIng(normalized);
    if (ingStem != null) {
      forms.add(ingStem);
    }
    final edStem = _stemFromEd(normalized);
    if (edStem != null) {
      forms.add(edStem);
    }
    return forms;
  }

  static String? _stemFromIng(String word) {
    if (!word.endsWith('ing') || word.length <= 4) {
      return null;
    }
    final base = word.substring(0, word.length - 3);
    final undoubled = _undoubleIngEdStem(base);
    for (final stem in [undoubled, '${undoubled}e', base, '${base}e']) {
      if (AslCoreLexicon.curriculumVerbs.contains(stem)) {
        return stem;
      }
    }
    if (EnglishLexicon.contains(word)) {
      return null;
    }
    for (final stem in [undoubled, '${undoubled}e', base, '${base}e']) {
      if (EnglishLexicon.contains(stem)) {
        return stem;
      }
    }
    return null;
  }

  static String? _stemFromEd(String word) {
    if (!word.endsWith('ed') || word.length <= 3) {
      return null;
    }
    final raw = word.substring(0, word.length - 2);
    final undoubled = _undoubleIngEdStem(raw);
    for (final stem in [undoubled, raw, '${undoubled}e', '${raw}e']) {
      if (AslCoreLexicon.curriculumVerbs.contains(stem)) {
        return stem;
      }
    }
    if (EnglishLexicon.contains(word)) {
      return null;
    }
    for (final stem in [undoubled, raw, '${undoubled}e', '${raw}e']) {
      if (EnglishLexicon.contains(stem)) {
        return stem;
      }
    }
    return null;
  }

  static String _undoubleIngEdStem(String stem) {
    if (stem.length < 2) {
      return stem;
    }
    final last = stem[stem.length - 1];
    final previous = stem[stem.length - 2];
    if (last == previous && !'aeiou'.contains(last)) {
      return stem.substring(0, stem.length - 1);
    }
    return stem;
  }

  /// Strip -es only for true -es plurals (boxes), not notes→not.
  static bool _shouldStripEsPlural(String word) {
    if (word.length < 5) {
      return false;
    }
    return word.endsWith('ches') ||
        word.endsWith('shes') ||
        word.endsWith('sses') ||
        word.endsWith('xes') ||
        word.endsWith('zes') ||
        word.endsWith('oes') ||
        word.endsWith('ates') ||
        word.endsWith('izes') ||
        word.endsWith('ifies');
  }

  static SignToken? _resolveForm(String normalized, SignLanguageSystem system) {
    if (system == SignLanguageSystem.isl) {
      final regional = _islRegional[normalized];
      if (regional != null) {
        return regional;
      }
    }

    final glossOverride = _glossOverrides[normalized];
    if (glossOverride != null) {
      return SignToken(
        id: _idOverrides[normalized] ?? normalized,
        gloss: glossOverride,
        system: system,
      );
    }

    if (_locativeCompound.hasMatch(normalized)) {
      return SignToken(
        id: normalized,
        gloss: normalized.toUpperCase(),
        system: system,
      );
    }

    if (normalized.startsWith('fs-') && normalized.length > 3) {
      return SignToken(
        id: normalized,
        gloss: normalized.toUpperCase(),
        system: system,
      );
    }

    final corpusGloss = AslCoreLexicon.corpusGlosses[normalized];
    if (corpusGloss != null) {
      return SignToken(
        id: normalized,
        gloss: corpusGloss,
        system: system,
      );
    }

    final pedagogyGloss = AslCoreLexicon.pedagogicalOverrides[normalized];
    if (pedagogyGloss != null) {
      return SignToken(
        id: AslCoreLexicon.pedagogicalIds[normalized] ?? normalized,
        gloss: pedagogyGloss,
        system: system,
      );
    }

    if (system == SignLanguageSystem.asl) {
      final certified = AslSignLexicon.lookup(normalized);
      if (certified != null) {
        return SignToken(
          id: certified.id,
          gloss: certified.gloss,
          system: system,
        );
      }
    }

    if (!EnglishLexicon.contains(normalized) &&
        !_grammarMarkers.contains(normalized)) {
      return null;
    }

    final gloss = normalized.toUpperCase();
    final id = _idOverrides[normalized] ?? normalized;
    return SignToken(id: id, gloss: gloss, system: system);
  }

  /// Personal names are fingerspelled letter-by-letter in ASL gloss notation.
  static List<SignToken> fingerspell(
    String word,
    SignLanguageSystem system, {
    bool fsLabel = false,
  }) {
    final tokens = <SignToken>[];
    for (final match in _letterPattern.allMatches(word)) {
      final letter = match.group(0)!;
      final lower = letter.toLowerCase();
      final gloss = fsLabel
          ? 'FS-${letter.toUpperCase()}'
          : letter.toUpperCase();
      tokens.add(
        SignToken(
          id: 'letter_$lower',
          gloss: gloss,
          system: system,
        ),
      );
    }
    return tokens;
  }

  static SignToken? tokenForGloss(String gloss, SignLanguageSystem system) {
    final normalizedGloss = gloss.trim().toUpperCase();
    if (normalizedGloss.isEmpty) {
      return null;
    }

    for (final entry in _glossOverrides.entries) {
      if (entry.value == normalizedGloss) {
        return resolve(entry.key, system);
      }
    }

    final normalized = normalizedGloss.toLowerCase();
    if (system == SignLanguageSystem.asl) {
      final certified = AslSignLexicon.lookup(normalized);
      if (certified != null && certified.gloss == normalizedGloss) {
        return SignToken(
          id: certified.id,
          gloss: certified.gloss,
          system: system,
        );
      }
    }

    if (EnglishLexicon.contains(normalized) ||
        _grammarMarkers.contains(normalized)) {
      return SignToken(
        id: _idOverrides[normalized] ?? normalized,
        gloss: normalizedGloss,
        system: system,
      );
    }
    return null;
  }

  static Map<String, SignToken> _regionalIslEntries() {
    return {
      'नहीं': SignToken(id: 'not', gloss: 'NOT', system: SignLanguageSystem.isl),
      'नमस्ते': SignToken(
        id: 'hello',
        gloss: 'HELLO',
        system: SignLanguageSystem.isl,
      ),
      'कैसे': SignToken(
        id: 'how',
        gloss: 'HOW',
        system: SignLanguageSystem.isl,
      ),
      'हैं': SignToken(
        id: 'you',
        gloss: 'YOU',
        system: SignLanguageSystem.isl,
      ),
      'आप': SignToken(
        id: 'you',
        gloss: 'YOU',
        system: SignLanguageSystem.isl,
      ),
      'आज': SignToken(
        id: 'today',
        gloss: 'TODAY',
        system: SignLanguageSystem.isl,
      ),
      'வணக்கம்': SignToken(
        id: 'hello',
        gloss: 'HELLO',
        system: SignLanguageSystem.isl,
      ),
      'எப்படி': SignToken(
        id: 'how',
        gloss: 'HOW',
        system: SignLanguageSystem.isl,
      ),
      'ഹലോ': SignToken(
        id: 'hello',
        gloss: 'HELLO',
        system: SignLanguageSystem.isl,
      ),
      'സുഖമാണോ': SignToken(
        id: 'how',
        gloss: 'HOW',
        system: SignLanguageSystem.isl,
      ),
      'give-you': SignToken(
        id: 'give-you',
        gloss: 'GIVE-YOU',
        system: SignLanguageSystem.isl,
      ),
      'give-me': SignToken(
        id: 'give-me',
        gloss: 'GIVE-ME',
        system: SignLanguageSystem.isl,
      ),
      'point-there': SignToken(
        id: 'point-there',
        gloss: 'POINT-THERE',
        system: SignLanguageSystem.isl,
      ),
      'point-there-plural': SignToken(
        id: 'point-there-plural',
        gloss: 'POINT-THERE-PLURAL',
        system: SignLanguageSystem.isl,
      ),
      'book-on': SignToken(
        id: 'book-on',
        gloss: 'BOOK-ON',
        system: SignLanguageSystem.isl,
      ),
      '3-day': SignToken(
        id: '3-day',
        gloss: '3-DAY',
        system: SignLanguageSystem.isl,
      ),
    };
  }
}
