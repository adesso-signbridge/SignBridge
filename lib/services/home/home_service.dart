import '../../core/services/microservice.dart';

class HomeActionCard {
  const HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.mode,
  });

  final String title;
  final String subtitle;
  final HomeActionMode mode;
}

enum HomeActionMode { hearForMe, speakForMe }

class HomeContent {
  const HomeContent({
    required this.quickPhrases,
    required this.actionCards,
    required this.selectedLanguage,
  });

  final List<String> quickPhrases;
  final List<HomeActionCard> actionCards;
  final String selectedLanguage;
}

abstract class HomeService implements Microservice {
  Future<HomeContent> fetchHomeContent();
}
