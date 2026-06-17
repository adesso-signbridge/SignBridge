import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/spoken_text_prep.dart';

void main() {
  test('inferYesNoQuestion without question mark', () {
    expect(SpokenTextPrep.inferYesNoQuestion('Are you coming'), isTrue);
    expect(SpokenTextPrep.inferYesNoQuestion('Do you understand me'), isTrue);
    expect(SpokenTextPrep.inferYesNoQuestion('What are you doing'), isFalse);
    expect(SpokenTextPrep.inferYesNoQuestion('Are you coming?'), isTrue);
  });

  test('normalizeForGloss maps Hindi tokens to English grammar', () {
    final normalized = SpokenTextPrep.normalizeForGloss(
      'मैं घर जाता हूँ',
      'HI',
    );
    expect(normalized.toLowerCase(), contains('i'));
    expect(normalized.toLowerCase(), contains('home'));
    expect(normalized.toLowerCase(), contains('go'));
  });
}
