import 'phrase_catalog.dart';
import 'phrases_service.dart';

final class LocalPhrasesService implements PhrasesService {
  @override
  String get serviceName => 'phrases-service';

  @override
  PhrasesUiCopy uiCopyFor(String languageCode) =>
      phrasesUiCopyFor(languageCode);

  @override
  List<PhraseCategory> categories() => PhraseCategory.values;

  @override
  List<PhraseItem> phrases({
    String categoryId = PhraseCatalog.allCategoryId,
    String searchQuery = '',
  }) {
    return PhraseCatalog.filter(categoryId: categoryId, query: searchQuery);
  }
}
