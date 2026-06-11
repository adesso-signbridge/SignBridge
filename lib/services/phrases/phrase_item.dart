import 'phrase_category.dart';

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
