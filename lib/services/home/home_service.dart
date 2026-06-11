import '../../core/services/microservice.dart';

class HomeLanguage {
  const HomeLanguage({required this.code, required this.label});

  final String code;
  final String label;
}

class HomeContent {
  const HomeContent({
    required this.selectedLanguageCode,
    required this.languages,
    required this.emptyStateMessage,
    required this.appVersion,
  });

  final String selectedLanguageCode;
  final List<HomeLanguage> languages;
  final String emptyStateMessage;
  final String appVersion;
}

abstract class HomeService implements Microservice {
  Future<HomeContent> fetchHomeContent();
}
