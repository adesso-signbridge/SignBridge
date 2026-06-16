import '../translate/sign_language_catalog.dart';
import '../translate/sign_language_system.dart';
import '../translate/sign_token.dart';

/// Maps AI gloss output to avatar animation tokens.
abstract final class GlossSequenceMapper {
  static List<SignToken> tokensFor({
    required List<String> glossSequence,
    required SignLanguageSystem system,
  }) {
    final tokens = <SignToken>[];
    for (final gloss in glossSequence) {
      final token = SignLanguageCatalog.tokenForGloss(gloss, system);
      if (tokens.isEmpty || tokens.last.id != token.id) {
        tokens.add(token);
      }
    }
    return tokens;
  }
}
