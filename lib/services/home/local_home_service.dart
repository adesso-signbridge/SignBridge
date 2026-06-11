import 'home_service.dart';

final class LocalHomeService implements HomeService {
  @override
  String get serviceName => 'home-service';

  @override
  Future<HomeContent> fetchHomeContent() async {
    return const HomeContent(
      selectedLanguageCode: 'ENG',
      languages: [
        HomeLanguage(code: 'ENG', label: 'English'),
        HomeLanguage(code: 'ML', label: 'മലയാളം'),
        HomeLanguage(code: 'HI', label: 'हिन्दी'),
        HomeLanguage(code: 'TA', label: 'தமிழ்'),
      ],
      emptyStateMessage:
          'No conversation yet.\nUse the buttons below to start.',
      appVersion: '1.0.0',
    );
  }
}
