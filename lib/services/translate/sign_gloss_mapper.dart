import 'sign_language_catalog.dart';
import 'sign_token.dart';

/// Maps spoken text to sign-language gloss tokens shown on the avatar chip.
abstract final class SignGlossMapper {
  static String currentGloss(String transcript, String languageCode) {
    return SignLanguageCatalog.activeToken(transcript, languageCode).gloss;
  }

  static String liveCaption(String transcript) {
    return transcript.trim();
  }

  static List<SignToken> signSequence(String transcript, String languageCode) {
    return SignLanguageCatalog.sequenceFor(transcript, languageCode);
  }

  static SignToken activeSign(String transcript, String languageCode) {
    return SignLanguageCatalog.activeToken(transcript, languageCode);
  }
}
