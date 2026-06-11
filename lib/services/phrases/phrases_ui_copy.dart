/// Localized strings for the Phrases tab.
class PhrasesUiCopy {
  const PhrasesUiCopy({
    required this.searchHint,
    required this.allLabel,
    required this.greetingsLabel,
    required this.medicalLabel,
    required this.transportLabel,
    required this.shoppingLabel,
    required this.emergencyLabel,
  });

  final String searchHint;
  final String allLabel;
  final String greetingsLabel;
  final String medicalLabel;
  final String transportLabel;
  final String shoppingLabel;
  final String emergencyLabel;

  String categoryLabel(String categoryId) {
    return switch (categoryId) {
      'greetings' => greetingsLabel,
      'medical' => medicalLabel,
      'transport' => transportLabel,
      'shopping' => shoppingLabel,
      'emergency' => emergencyLabel,
      _ => allLabel,
    };
  }
}

const _phrasesUiCopyByLanguage = <String, PhrasesUiCopy>{
  'ENG': PhrasesUiCopy(
    searchHint: 'Search phrases…',
    allLabel: 'All',
    greetingsLabel: 'Greetings',
    medicalLabel: 'Medical',
    transportLabel: 'Transport',
    shoppingLabel: 'Shopping',
    emergencyLabel: 'Emergency',
  ),
  'ML': PhrasesUiCopy(
    searchHint: 'വാചകങ്ങൾ തിരയുക…',
    allLabel: 'എല്ലാം',
    greetingsLabel: 'ആശംസകൾ',
    medicalLabel: 'മെഡിക്കൽ',
    transportLabel: 'ഗതാഗതം',
    shoppingLabel: 'ഷോപ്പിംഗ്',
    emergencyLabel: 'അടിയന്തരം',
  ),
  'HI': PhrasesUiCopy(
    searchHint: 'वाक्यांश खोजें…',
    allLabel: 'सभी',
    greetingsLabel: 'अभिवादन',
    medicalLabel: 'चिकित्सा',
    transportLabel: 'परिवहन',
    shoppingLabel: 'खरीदारी',
    emergencyLabel: 'आपातकाल',
  ),
  'TA': PhrasesUiCopy(
    searchHint: 'சொற்றொடர்களைத் தேடுங்கள்…',
    allLabel: 'அனைத்தும்',
    greetingsLabel: 'வாழ்த்துக்கள்',
    medicalLabel: 'மருத்துவம்',
    transportLabel: 'போக்குவரத்து',
    shoppingLabel: 'கடைப்பிடித்தல்',
    emergencyLabel: 'அவசரம்',
  ),
};

PhrasesUiCopy phrasesUiCopyFor(String languageCode) {
  return _phrasesUiCopyByLanguage[languageCode] ??
      _phrasesUiCopyByLanguage['ENG']!;
}
