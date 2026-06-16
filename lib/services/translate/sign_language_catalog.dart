import 'sign_language_system.dart';
import 'sign_token.dart';

/// Lexicon mapping spoken words to ASL / ISL gloss tokens and avatar pose ids.
abstract final class SignLanguageCatalog {
  static const _thinking = SignToken.thinking;

  static const _aslLexicon = <String, SignToken>{
    'hello': SignToken(
      id: 'hello',
      gloss: 'HELLO',
      system: SignLanguageSystem.asl,
    ),
    'hi': SignToken(
      id: 'hello',
      gloss: 'HELLO',
      system: SignLanguageSystem.asl,
    ),
    'how': SignToken(id: 'how', gloss: 'HOW', system: SignLanguageSystem.asl),
    'are': SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.asl),
    'you': SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.asl),
    'today': SignToken(
      id: 'today',
      gloss: 'TODAY',
      system: SignLanguageSystem.asl,
    ),
    'thank': SignToken(
      id: 'thank_you',
      gloss: 'THANK-YOU',
      system: SignLanguageSystem.asl,
    ),
    'thanks': SignToken(
      id: 'thank_you',
      gloss: 'THANK-YOU',
      system: SignLanguageSystem.asl,
    ),
    'please': SignToken(
      id: 'please',
      gloss: 'PLEASE',
      system: SignLanguageSystem.asl,
    ),
    'help': SignToken(
      id: 'help',
      gloss: 'HELP',
      system: SignLanguageSystem.asl,
    ),
    'yes': SignToken(id: 'yes', gloss: 'YES', system: SignLanguageSystem.asl),
    'no': SignToken(id: 'no', gloss: 'NO', system: SignLanguageSystem.asl),
    'my': SignToken(id: 'my', gloss: 'MY', system: SignLanguageSystem.asl),
    'name': SignToken(
      id: 'name',
      gloss: 'NAME',
      system: SignLanguageSystem.asl,
    ),
    'is': SignToken(id: 'is', gloss: 'IS', system: SignLanguageSystem.asl),
    'good': SignToken(
      id: 'good',
      gloss: 'GOOD',
      system: SignLanguageSystem.asl,
    ),
    'looking': SignToken(
      id: 'looking',
      gloss: 'LOOK',
      system: SignLanguageSystem.asl,
    ),
    'everything': SignToken(
      id: 'everything',
      gloss: 'ALL',
      system: SignLanguageSystem.asl,
    ),
  };

  static const _islLexicon = <String, SignToken>{
    'hello': SignToken(
      id: 'hello',
      gloss: 'HELLO',
      system: SignLanguageSystem.isl,
    ),
    'hi': SignToken(
      id: 'hello',
      gloss: 'HELLO',
      system: SignLanguageSystem.isl,
    ),
    'how': SignToken(id: 'how', gloss: 'HOW', system: SignLanguageSystem.isl),
    'are': SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.isl),
    'you': SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.isl),
    'today': SignToken(
      id: 'today',
      gloss: 'TODAY',
      system: SignLanguageSystem.isl,
    ),
    'thank': SignToken(
      id: 'thank_you',
      gloss: 'THANK-YOU',
      system: SignLanguageSystem.isl,
    ),
    'thanks': SignToken(
      id: 'thank_you',
      gloss: 'THANK-YOU',
      system: SignLanguageSystem.isl,
    ),
    'please': SignToken(
      id: 'please',
      gloss: 'PLEASE',
      system: SignLanguageSystem.isl,
    ),
    'help': SignToken(
      id: 'help',
      gloss: 'HELP',
      system: SignLanguageSystem.isl,
    ),
    'yes': SignToken(id: 'yes', gloss: 'YES', system: SignLanguageSystem.isl),
    'no': SignToken(id: 'no', gloss: 'NO', system: SignLanguageSystem.isl),
    'my': SignToken(id: 'my', gloss: 'MY', system: SignLanguageSystem.isl),
    'name': SignToken(
      id: 'name',
      gloss: 'NAME',
      system: SignLanguageSystem.isl,
    ),
    'is': SignToken(id: 'is', gloss: 'IS', system: SignLanguageSystem.isl),
    'good': SignToken(
      id: 'good',
      gloss: 'GOOD',
      system: SignLanguageSystem.isl,
    ),
    'looking': SignToken(
      id: 'looking',
      gloss: 'LOOK',
      system: SignLanguageSystem.isl,
    ),
    'everything': SignToken(
      id: 'everything',
      gloss: 'ALL',
      system: SignLanguageSystem.isl,
    ),
    // Hindi
    'नमस्ते': SignToken(
      id: 'hello',
      gloss: 'HELLO',
      system: SignLanguageSystem.isl,
    ),
    'कैसे': SignToken(id: 'how', gloss: 'HOW', system: SignLanguageSystem.isl),
    'हैं': SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.isl),
    'आप': SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.isl),
    'आज': SignToken(
      id: 'today',
      gloss: 'TODAY',
      system: SignLanguageSystem.isl,
    ),
    // Tamil
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
    // Malayalam
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
  };

  static List<SignToken> sequenceFor(String transcript, String languageCode) {
    final system = SignLanguageSystem.forSpokenLanguage(languageCode);
    final lexicon = system == SignLanguageSystem.asl
        ? _aslLexicon
        : _islLexicon;
    final words = _words(transcript);
    if (words.isEmpty) {
      return const [];
    }

    final tokens = <SignToken>[];
    for (final word in words) {
      final normalized = _normalize(word);
      final token = lexicon[normalized] ?? _fallbackToken(normalized, system);
      if (tokens.isEmpty || tokens.last.id != token.id) {
        tokens.add(token);
      }
    }
    return tokens;
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
    final normalizedGloss = gloss.trim().toUpperCase();
    if (normalizedGloss.isEmpty) {
      return _fallbackToken('', system);
    }

    final lexicon = system == SignLanguageSystem.asl
        ? _aslLexicon
        : _islLexicon;
    for (final token in lexicon.values) {
      if (token.gloss == normalizedGloss) {
        return token;
      }
    }

    return _fallbackToken(normalizedGloss.toLowerCase(), system);
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

  static List<String> _words(String transcript) {
    return transcript
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  static String _normalize(String word) {
    final trimmed = word.trim();
    final stripped = trimmed.replaceAll(
      RegExp(r"^[\p{P}\p{S}']+|[\p{P}\p{S}']+$", unicode: true),
      '',
    );
    return stripped.toLowerCase();
  }
}
