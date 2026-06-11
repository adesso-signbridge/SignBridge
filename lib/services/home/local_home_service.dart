import 'home_service.dart';

final class LocalHomeService implements HomeService {
  @override
  String get serviceName => 'home-service';

  @override
  Future<HomeContent> fetchHomeContent() async {
    return const HomeContent(
      selectedLanguage: 'ENG',
      actionCards: [
        HomeActionCard(
          title: 'Hear for me',
          subtitle: 'Voice → Sign',
          mode: HomeActionMode.hearForMe,
        ),
        HomeActionCard(
          title: 'Speak for me',
          subtitle: 'Sign → Voice',
          mode: HomeActionMode.speakForMe,
        ),
      ],
      quickPhrases: [
        'Hello, nice to meet you.',
        'Please write it down.',
        'I need help.',
      ],
    );
  }
}
