import '../../core/services/microservice.dart';

/// Converts a spoken caption into sign-language gloss tokens.
abstract class GlossService implements Microservice {
  /// Returns ordered UPPERCASE gloss tokens for [caption] (e.g.
  /// `['HELLO', 'HOW', 'YOU']`). Returns an empty list when no gloss could be
  /// produced.
  Future<List<String>> requestGloss({
    required String jobId,
    required String caption,
    required String signLanguage,
  });
}
