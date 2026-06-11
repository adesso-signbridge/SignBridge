import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/phrases/phrase_catalog.dart';
import 'package:sign_bridge/services/phrases/phrase_category.dart';

void main() {
  test('catalog contains 100 daily phrases across five sections', () {
    expect(PhraseCatalog.phrases.length, 100);

    for (final category in PhraseCategory.values) {
      final count = PhraseCatalog.phrases
          .where((phrase) => phrase.category == category)
          .length;
      expect(count, 20, reason: '${category.id} should have 20 phrases');
    }
  });

  test('filter by category and search query', () {
    final greetings = PhraseCatalog.filter(categoryId: 'greetings');
    expect(
      greetings.every((p) => p.category == PhraseCategory.greetings),
      isTrue,
    );

    final hello = PhraseCatalog.filter(query: 'hello');
    expect(hello.any((p) => p.text == 'Hello'), isTrue);

    final medicalSearch = PhraseCatalog.filter(
      categoryId: 'medical',
      query: 'ambulance',
    );
    expect(medicalSearch.length, 1);
    expect(medicalSearch.first.text, 'Call an ambulance');
  });
}
