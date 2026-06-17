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

  List<String> gloss(String english) {
    return SignGlossMapper.signSequence(english, 'HI')
        .map((t) => t.gloss)
        .toList();
  }

  test('ISL sentence structure', () {
    expect(gloss('I went to school yesterday'), [
      'YESTERDAY',
      'ME',
      'SCHOOL',
      'GO',
    ]);
    expect(gloss('I eat an apple'), ['ME', 'APPLE', 'EAT']);
    expect(gloss('That book, I like it'), ['BOOK', 'THAT', 'ME', 'LIKE']);
    expect(gloss('Where are you going?'), [
      'YOU',
      'GO',
      'WHERE?',
    ]);
    expect(gloss('Are you coming?'), ['[y/n-q]', 'YOU', 'COME?']);
    expect(gloss('Are you coming'), ['[y/n-q]', 'YOU', 'COME?']);
    expect(gloss("I don't know"), [
      'ME',
      'KNOW',
      'NOT',
    ]);
  });

  test('ISL word mechanics', () {
    expect(gloss('The boy is happy'), ['BOY', 'HAPPY']);
    expect(gloss('I am tired'), ['ME', 'TIRED']);
    expect(gloss('Big house'), ['HOUSE', 'BIG']);
    expect(gloss('He is happy'), ['POINT-THERE', 'HAPPY']);
  });

  test('ISL spatial and compounds', () {
    expect(gloss('Book on table'), ['TABLE', 'BOOK-ON']);
    expect(gloss('I give you water'), ['ME', 'GIVE-YOU']);
    expect(gloss('I stayed home because it rained'), [
      'RAIN',
      'HOME',
      'ME',
      'STAY',
    ]);
    expect(gloss('If rain comes, game cancelled'), [
      'IF',
      'RAIN',
      'GAME',
      'CANCEL',
    ]);
  });

  test('ISL time numbers and names', () {
    expect(gloss('Today I go to work'), ['TODAY', 'ME', 'WORK', 'GO']);
    expect(gloss('3 days'), ['3-DAY']);
    expect(gloss('I am 25 years old'), ['ME', 'AGE', '25']);
    final name = gloss('My name is Adarsha');
    expect(name.take(2).toList(), ['MY', 'NAME']);
    expect(name.length, greaterThan(2));
  });

  test('romanized Hindi name question maps to YOUR NAME WHAT', () {
    final glosses = SignGlossMapper.signSequence('tumara nam kya hai', 'HI')
        .map((t) => t.gloss)
        .toList();
    expect(glosses, ['YOUR', 'NAME', 'WHAT?']);
  });
}
