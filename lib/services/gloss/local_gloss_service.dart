import '../translate/sign_language_catalog.dart';
import '../translate/sign_language_system.dart';
import 'gloss_service.dart';

/// Offline gloss generation using the on-device lexicon.
final class LocalGlossService implements GlossService {
  @override
  String get serviceName => 'gloss-service';

  @override
  Future<List<String>> requestGloss({
    required String jobId,
    required String caption,
    required String signLanguage,
  }) async {
    final system = signLanguage.toUpperCase().contains('ISL')
        ? SignLanguageSystem.isl
        : SignLanguageSystem.asl;
    final languageCode = system == SignLanguageSystem.isl ? 'HI' : 'ENG';
    return SignLanguageCatalog.sequenceFor(
      caption,
      languageCode,
    ).map((token) => token.gloss).toList();
  }
}
