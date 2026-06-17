import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('ISL grammar rules audit', () {
    final sentences = [
      'I went to school yesterday',
      'I eat an apple',
      'That book, I like it',
      'Where are you going?',
      'Are you coming?',
      "I don't know",
      'The boy is happy',
      'I am tired',
      'Big house',
      'Book on table',
      'I give you water',
      'He is happy',
      'I stayed home because it rained',
      'If rain comes, game cancelled',
      'I am 25 years old',
      'My name is Adarsha',
      'Today I go to work',
      '3 days',
    ];

    var hidden = 0;
    for (final sentence in sentences) {
      final glosses =
          SignGlossMapper.signSequence(sentence, 'HI').map((t) => t.gloss).toList();
      if (glosses.isEmpty) {
        hidden++;
        // ignore: avoid_print
        print('HIDDEN: $sentence');
      }
    }

    // ignore: avoid_print
    print('ISL audit: ${sentences.length - hidden}/${sentences.length} with gloss');
    expect(hidden, 0);
  });
}
