import 'phrase_category.dart';
import 'phrase_item.dart';

/// Built-in daily phrases for mute / non-verbal users (Speak for me).
abstract final class PhraseCatalog {
  static const allCategoryId = 'all';

  static const List<PhraseItem> phrases = [
    // Greetings (20)
    PhraseItem(
      id: 'greet_hello',
      text: 'Hello',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_thanks',
      text: 'Thank you',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_deaf_mute',
      text: 'I am deaf / mute',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_write_down',
      text: 'Please write it down',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_nice_meet',
      text: 'Nice to meet you',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_goodbye',
      text: 'Goodbye',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_morning',
      text: 'Good morning',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_evening',
      text: 'Good evening',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_how_are_you',
      text: 'How are you?',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_please_wait',
      text: 'Please wait',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_excuse_me',
      text: 'Excuse me',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_sorry',
      text: 'Sorry',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_welcome',
      text: "You're welcome",
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_see_you',
      text: 'See you later',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_my_name',
      text: 'My name is',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_dont_understand',
      text: "I don't understand",
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_repeat',
      text: 'Can you repeat that?',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_slowly',
      text: 'Please speak slowly',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(
      id: 'greet_yes',
      text: 'Yes',
      category: PhraseCategory.greetings,
    ),
    PhraseItem(id: 'greet_no', text: 'No', category: PhraseCategory.greetings),

    // Medical (20)
    PhraseItem(
      id: 'med_doctor',
      text: 'I need a doctor',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_allergy',
      text: 'I have an allergy',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_ambulance',
      text: 'Call an ambulance',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_medication',
      text: 'I take medication',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_hospital',
      text: 'Where is the hospital?',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_pain',
      text: 'I feel pain here',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_sick',
      text: 'I am sick',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_help',
      text: 'I need help',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_fever',
      text: 'I have a fever',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_dizzy',
      text: 'I feel dizzy',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_diabetic',
      text: 'I am diabetic',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_pregnant',
      text: 'I am pregnant',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_blood_type',
      text: 'My blood type is',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_pharmacy',
      text: 'I need a pharmacy',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_chest_pain',
      text: 'I have chest pain',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_breathe',
      text: 'I cannot breathe',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_accident',
      text: 'I had an accident',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_wheelchair',
      text: 'I need a wheelchair',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_allergic_to',
      text: 'I am allergic to',
      category: PhraseCategory.medical,
    ),
    PhraseItem(
      id: 'med_emergency',
      text: 'This is a medical emergency',
      category: PhraseCategory.medical,
    ),

    // Transport (20)
    PhraseItem(
      id: 'trans_bus_stop',
      text: 'Where is the bus stop?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_address',
      text: 'Take me to this address',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_ticket',
      text: 'How much is the ticket?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_exit',
      text: 'Where is the exit?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_taxi',
      text: 'I need a taxi',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_train',
      text: 'Where is the train station?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_airport',
      text: 'Where is the airport?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_platform',
      text: 'Which platform?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_one_ticket',
      text: 'One ticket please',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_missed_bus',
      text: 'I missed my bus',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_right_bus',
      text: 'Is this the right bus?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_stop_here',
      text: 'Stop here please',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_how_long',
      text: 'How long will it take?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_directions',
      text: 'I need directions',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_parking',
      text: 'Where is the parking?',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_turn_left',
      text: 'Turn left',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_turn_right',
      text: 'Turn right',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_go_straight',
      text: 'Go straight',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_lost',
      text: 'I am lost',
      category: PhraseCategory.transport,
    ),
    PhraseItem(
      id: 'trans_call_cab',
      text: 'Please call a cab',
      category: PhraseCategory.transport,
    ),

    // Shopping (20)
    PhraseItem(
      id: 'shop_cost',
      text: 'How much does this cost?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_this_one',
      text: 'I would like this one',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_smaller',
      text: 'Do you have a smaller size?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_card',
      text: 'Can I pay by card?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_cash',
      text: 'Do you accept cash?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_looking',
      text: 'I am just looking',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_try_on',
      text: 'Can I try this on?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_fitting',
      text: 'Where is the fitting room?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_receipt',
      text: 'I need a receipt',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_discount',
      text: 'Is there a discount?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_expensive',
      text: 'That is too expensive',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_take_it',
      text: "I'll take it",
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_color',
      text: 'Do you have this in another color?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_stock',
      text: 'Is this in stock?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_cashier',
      text: 'Where is the cashier?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_return',
      text: 'Can I return this?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_bag',
      text: 'I need a bag please',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_two',
      text: 'How much for two?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_open',
      text: 'Are you open?',
      category: PhraseCategory.shopping,
    ),
    PhraseItem(
      id: 'shop_closed',
      text: 'What time do you close?',
      category: PhraseCategory.shopping,
    ),

    // Emergency (20)
    PhraseItem(
      id: 'em_help',
      text: 'Help!',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_police',
      text: 'Call the police',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_lost',
      text: 'I am lost',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_assistance',
      text: 'I need assistance',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_fire',
      text: 'Fire!',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_call_emergency',
      text: 'Call emergency services',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_help_now',
      text: 'I need help now',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_hurt',
      text: 'Someone is hurt',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_danger',
      text: 'Danger!',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_evacuate',
      text: 'Please evacuate',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_cannot_hear',
      text: 'I cannot hear',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_cannot_speak',
      text: 'I cannot speak',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_med_emergency',
      text: 'Medical emergency',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_stay',
      text: 'Please stay with me',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_where_am_i',
      text: 'Where am I?',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_translator',
      text: 'I need a translator',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_call_family',
      text: 'Please call my family',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_in_danger',
      text: 'I am in danger',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(
      id: 'em_help_please',
      text: 'Help me please',
      category: PhraseCategory.emergency,
    ),
    PhraseItem(id: 'em_sos', text: 'SOS', category: PhraseCategory.emergency),
  ];

  static List<PhraseItem> filter({
    String categoryId = allCategoryId,
    String query = '',
    String languageCode = 'ENG',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return phrases.where((phrase) {
      final matchesCategory =
          categoryId == allCategoryId || phrase.category.id == categoryId;
      if (!matchesCategory) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final localized = phrase.textFor(languageCode).toLowerCase();
      return localized.contains(normalizedQuery) ||
          phrase.text.toLowerCase().contains(normalizedQuery) ||
          phrase.category.defaultLabel.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}
