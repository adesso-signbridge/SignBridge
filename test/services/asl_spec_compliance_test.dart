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
    return SignGlossMapper.signSequence(english, 'ENG')
        .map((t) => t.gloss)
        .toList();
  }

  test('Module 1 foundational structures', () {
    expect(gloss('I went to the store yesterday'), [
      'YESTERDAY',
      'STORE',
      'ME',
      'GO',
    ]);
    expect(gloss('I like dogs'), ['DOG', 'ME', 'LIKE']);
    expect(gloss('If it rains, the game is cancelled'), [
      'IF',
      'RAIN',
      'GAME',
      'CANCEL',
    ]);
    expect(gloss('I eat an apple'), ['ME', 'EAT', 'APPLE', 'ME']);
  });

  test('Module 2 interrogative negative rhetorical', () {
    expect(gloss('Why did you go?'), [
      'YOU',
      'GO',
      'WHY',
      '[wh-q]',
    ]);
    expect(gloss('Are you Deaf?'), [
      '[y/n-q]',
      'YOU',
      'DEAF',
      'YOU',
    ]);
    final late = gloss('I am late because traffic was heavy');
    expect(late, contains('LATE'));
    expect(late, contains('[rh-q]'));
    expect(late, contains('WHY'));
    expect(late, contains('TRAFFIC'));
    expect(gloss('I cannot cook'), [
      'ME',
      'COOK',
      'CANNOT',
      '[headshake]',
    ]);
  });

  test('Module 3 word mechanics', () {
    expect(gloss('The car is red'), ['CAR', 'RED']);
    expect(gloss('The boy sees a dog'), ['BOY', 'SEE', 'DOG']);
    expect(gloss('I am a teacher'), ['ME', 'TEACHER']);
  });

  test('Module 4 directional verbs', () {
    expect(gloss('I give you'), ['ME', '1-GIVE-YOU', 'ME']);
    expect(gloss('You tell me'), ['YOU', 'TELL-ME', 'YOU']);
  });

  test('Module 5 numerical incorporation rule of 9', () {
    expect(gloss('I am 5 years old'), ['ME', '5-YEARS-OLD']);
    final age12 = gloss('I am 12 years old');
    expect(age12, ['ME', '12', 'YEARS-OLD']);
    expect(gloss('3 weeks ago'), ['3-WEEKS-AGO']);
    expect(gloss('12 weeks ago'), ['12', 'WEEK', 'PAST']);
  });

  test('Module 5 FINISH aspect for auxiliary HAVE', () {
    final eaten = gloss('I have eaten');
    expect(eaten, contains('ME'));
    expect(eaten, contains('EAT'));
    expect(eaten, contains('FINISH'));
    expect(gloss('I ran yesterday'), ['YESTERDAY', 'ME', 'RUN']);
  });

  test('Module 5 AND conjunction omitted', () {
    expect(gloss('I like dogs and cats'), ['DOG', 'CAT', 'ME', 'LIKE']);
    expect(
      gloss('I want coffee and tea').where((g) => g == 'AND'),
      isEmpty,
    );
  });

  test('Module 6 locatives spatial loci and full NMM', () {
    expect(gloss('The phone is on the table'), [
      'TABLE',
      'PHONE-ON-TOP',
    ]);
    expect(gloss('The book is under the table'), [
      'TABLE',
      'BOOK-UNDER',
    ]);
    expect(gloss('The book is in the bag'), [
      'BAG',
      'BOOK-IN',
    ]);
    expect(gloss('John likes Mary'), [
      'JOHN',
      'IX-a',
      'LIKE',
      'MARY',
      'IX-b',
    ]);
    final routine = gloss('I always eat breakfast');
    expect(routine, contains('[mm]'));
    final intense = gloss('The car is very red');
    expect(intense, contains('[cha]'));
    final accidental = gloss('I dropped the phone accidentally');
    expect(accidental, contains('[th]'));
    final close = gloss('The store is close');
    expect(close, contains('[cs]'));
  });

  test('Rule of 9 in dialogue phrases', () {
    expect(
      gloss("I've had a fever for two days").where((g) => g.length == 1),
      isEmpty,
    );
    expect(
      gloss(
        "I'm a software developer with five years of experience in mobile applications",
      ).where((g) => g.length == 1),
      isEmpty,
    );
  });
}
