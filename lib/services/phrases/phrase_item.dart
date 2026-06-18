import 'phrase_category.dart';
import 'phrase_localizations.dart';

/// One tap-to-speak quick phrase.
class PhraseItem {
  const PhraseItem({
    required this.id,
    required this.text,
    required this.category,
  });

  final String id;
  final String text;
  final PhraseCategory category;
}

extension PhraseItemLocalization on PhraseItem {
  String textFor(String languageCode) {
    return PhraseLocalizations.text(
      id,
      languageCode,
      fallback: text,
    );
  }
}
