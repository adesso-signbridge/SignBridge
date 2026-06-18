import '../../core/services/microservice.dart';

import 'phrase_catalog.dart';
import 'phrase_category.dart';
import 'phrase_item.dart';
import 'phrases_ui_copy.dart';

export 'phrase_category.dart';
export 'phrase_item.dart';
export 'phrase_speech_service.dart';
export 'phrases_ui_copy.dart';

abstract class PhrasesService implements Microservice {
  PhrasesUiCopy uiCopyFor(String languageCode);

  List<PhraseCategory> categories();

  List<PhraseItem> phrases({
    String categoryId = PhraseCatalog.allCategoryId,
    String searchQuery = '',
    String languageCode = 'ENG',
  });
}
