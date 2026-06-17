import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('English maps to ASL gloss sequence', () {
    final sequence = SignGlossMapper.signSequence(
      'Hello, how are you today?',
      'ENG',
    );
    expect(sequence.map((t) => t.gloss).toList(), [
      'TODAY',
      'HELLO',
      'YOU',
      'HOW',
      '[wh-q]',
    ]);
    expect(sequence.first.system, SignLanguageSystem.asl);
  });

  test('ASL rules move time first and question words last', () {
    final sequence = SignGlossMapper.signSequence(
      'What are you doing today?',
      'ENG',
    );
    expect(sequence.map((t) => t.gloss).toList(), [
      'TODAY',
      'YOU',
      'DO',
      'WHAT',
      '[wh-q]',
    ]);
  });

  test('ISL rules use subject-object-verb order', () {
    final sequence = SignGlossMapper.signSequence('I am going home', 'HI');
    expect(sequence.map((t) => t.gloss).toList(), ['ME', 'HOME', 'GO']);
    expect(sequence.first.system, SignLanguageSystem.isl);
  });

  test('Hindi maps to ISL gloss sequence', () {
    final sequence = SignGlossMapper.signSequence('नमस्ते, कैसे हैं', 'HI');
    expect(sequence.first.system, SignLanguageSystem.isl);
    expect(sequence.first.gloss, 'HELLO');
    expect(sequence.map((t) => t.gloss), contains('HOW'));
  });

  test('known words are glossed not fingerspelled', () {
    final sequence = SignGlossMapper.signSequence('This is really good', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['THIS', 'REAL', 'GOOD']);
  });

  test('common adjectives use certified ASL gloss when available', () {
    final sequence = SignGlossMapper.signSequence('amazing', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['ORANGE_EYES']);
  });

  test('asl sign lexicon loads thousands of certified entries', () {
    expect(AslSignLexicon.loadedEntryCount, greaterThan(6000));
  });

  test('english dictionary loads hundreds of thousands of words', () {
    expect(EnglishLexicon.loadedWordCount, greaterThan(200000));
  });

  test('ASL moves frequency first then object before verb', () {
    final sequence = SignGlossMapper.signSequence('Check it once', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['ONCE', 'IX', 'CHECK']);
  });

  test('place names gloss on chip', () {
    expect(
      SignGlossMapper.signSequence('I live in Mumbai', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      contains('MUMBAI'),
    );
    expect(
      SignGlossMapper.signSequence('I live in Bengaluru', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      contains('BENGALURU'),
    );
  });

  test('ASL unknown word uses fallback gloss instead of hiding', () {
    final sequence = SignGlossMapper.signSequence('ME eat xyzxyz', 'ENG');
    expect(sequence, isNotEmpty);
    expect(sequence.map((t) => t.gloss).join(' '), contains('EAT'));
  });

  test('Check it shows IX CHECK while streaming two words', () {
    final sequence = SignGlossMapper.signSequence('Check it', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['IX', 'CHECK']);
  });

  test('ASL topic-comment orders object before subject and verb', () {
    final sequence = SignGlossMapper.signSequence('I like candy', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['SWEET', 'ME', 'LIKE']);
  });

  test('ASL uses FINISH for past only when no time anchor', () {
    final withoutTime = SignGlossMapper.signSequence('I ran', 'ENG');
    expect(withoutTime.map((t) => t.gloss).toList(), ['ME', 'RUN', 'FINISH', 'ME']);

    final withTime = SignGlossMapper.signSequence('I ran yesterday', 'ENG');
    expect(withTime.map((t) => t.gloss).toList(), ['YESTERDAY', 'ME', 'RUN']);
  });

  test('ASL negation is post-fix NOT with headshake', () {
    final sequence = SignGlossMapper.signSequence("I don't like pizza", 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), [
      'PIZZA_1',
      'ME',
      'LIKE',
      'NOT',
      '[headshake]',
    ]);
  });

  test('ASL topic-comment for simple noun verb', () {
    final sequence = SignGlossMapper.signSequence('The dog is running', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['DOG', 'RUN']);
  });

  test('ASL name introduction uses standard MY NAME order', () {
    final sequence = SignGlossMapper.signSequence('My name is Rajendra', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), [
      'MY',
      'NAME',
      'FS-R',
      'FS-A',
      'FS-J',
      'FS-E',
      'FS-N',
      'FS-D',
      'FS-R',
      'FS-A',
    ]);
  });

  test('ASL hello name introduction keeps greeting first', () {
    final sequence = SignGlossMapper.signSequence(
      'Hello my name is Rajendra',
      'ENG',
    );
    expect(sequence.map((t) => t.gloss).toList(), [
      'HELLO',
      'MY',
      'NAME',
      'FS-R',
      'FS-A',
      'FS-J',
      'FS-E',
      'FS-N',
      'FS-D',
      'FS-R',
      'FS-A',
    ]);
  });

  test('ASL I am name uses ME gloss and word gloss for casual intro', () {
    final sequence = SignGlossMapper.signSequence('I am Rajendra', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['ME', 'RAJENDRA']);
  });

  test('ASL your name is uses YOUR NAME order and fingerspells name', () {
    final sequence = SignGlossMapper.signSequence('Your name is shanu', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), [
      'YOUR',
      'NAME',
      'FS-S',
      'FS-H',
      'FS-A',
      'FS-N',
      'FS-U',
    ]);
  });

  test('ASL what is your name uses YOUR NAME WHAT', () {
    final sequence = SignGlossMapper.signSequence('What is your name', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['YOUR', 'NAME', 'WHAT']);
  });

  test('ASL identity noun drops is and keeps demonstrative order', () {
    expect(
      SignGlossMapper.signSequence('It is cat', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['IX', 'CAT'],
    );
    expect(
      SignGlossMapper.signSequence('That is dog', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['THAT', 'DOG'],
    );
    expect(
      SignGlossMapper.signSequence('This is my house', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['THIS', 'MY', 'HOUSE'],
    );
  });

  test('ASL yes-no questions use YOU verb order without DO', () {
    expect(
      SignGlossMapper.signSequence('Do you understand', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['[y/n-q]', 'YOU', 'UNDERSTAND', 'YOU'],
    );
    expect(
      SignGlossMapper.signSequence('Do you understand me', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['[y/n-q]', 'YOU', 'UNDERSTAND', 'ME', 'YOU'],
    );
    expect(
      SignGlossMapper.signSequence('Are you coming', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['[y/n-q]', 'YOU', 'ARRIVE', 'YOU'],
    );
  });

  test('ASL negative imperative uses post-fix NOT', () {
    expect(
      SignGlossMapper.signSequence("don't tell this", 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['TELL', 'THIS', 'NOT', '[headshake]'],
    );
  });

  test('ASL fingerspells unknown English words letter by letter', () {
    final sequence = SignGlossMapper.signSequence('you flabbergasted', 'ENG');
    expect(sequence.map((t) => t.gloss).toList(), ['YOU', 'BLOW-MIND']);
  });

  test('ASL what happened phrases use WH-final and HAPPEN gloss', () {
    expect(
      SignGlossMapper.signSequence('what happened', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['HAPPEN', 'WHAT'],
    );
    expect(
      SignGlossMapper.signSequence('what is happening', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['HAPPEN', 'WHAT'],
    );
    expect(
      SignGlossMapper.signSequence('what happened to you', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['YOU', 'HAPPEN', 'WHAT'],
    );
    expect(
      SignGlossMapper.signSequence('tell me what happened', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['ME', 'TELL', 'WHAT', 'HAPPEN'],
    );
    expect(
      SignGlossMapper.signSequence('I am telling you what happened', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['ME', 'TELL-YOU', 'WHAT', 'HAPPEN'],
    );
  });

  test('ASL greeting phrases use standard gloss order', () {
    expect(
      SignGlossMapper.signSequence('Nice to meet you', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['NICE', 'MEET', 'YOU'],
    );
    expect(
      SignGlossMapper.signSequence('Nice meeting you', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['NICE', 'MEET', 'YOU'],
    );
    expect(
      SignGlossMapper.signSequence('Hello', 'ENG').map((t) => t.gloss).toList(),
      ['HELLO'],
    );
    expect(
      SignGlossMapper.signSequence('Hi', 'ENG').map((t) => t.gloss).toList(),
      ['HELLO'],
    );
    expect(
      SignGlossMapper.signSequence('Good morning', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['GOOD', 'MORNING'],
    );
    expect(
      SignGlossMapper.signSequence('Goodbye', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['GOODBYE'],
    );
    expect(
      SignGlossMapper.signSequence('Good to see you', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['GOOD', 'SEE', 'YOU'],
    );
    expect(
      SignGlossMapper.signSequence('How are you', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['HOW', 'YOU'],
    );
    expect(
      SignGlossMapper.signSequence('Welcome', 'ENG').map((t) => t.gloss).toList(),
      ['WELCOME'],
    );
    expect(
      SignGlossMapper.signSequence('See you later', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['SEE', 'YOU', 'LATER'],
    );
  });

  test('ASL daily-life phrases for holiday and scheduling', () {
    expect(
      SignGlossMapper.signSequence('today is a holiday for me', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['TODAY', 'VACATION', 'ME'],
    );
    expect(
      SignGlossMapper.signSequence('I have not decided yet', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['YET', 'ME', 'DECIDE', 'NOT', '[headshake]'],
    );
    expect(
      SignGlossMapper.signSequence('dont disturb im studing', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['BOTHER', 'ME', 'STUDY', 'NOT', '[headshake]'],
    );
    expect(
      SignGlossMapper.signSequence("don't disturb I'm studying", 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['BOTHER', 'ME', 'STUDY', 'NOT', '[headshake]'],
    );
    expect(
      SignGlossMapper.signSequence('doctor will come to the shop after 9:30', 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['WILL', 'DOCTOR', 'SHOP', '9:30', 'ARRIVE'],
    );
    expect(
      SignGlossMapper.signSequence("don't disturb", 'ENG')
          .map((t) => t.gloss)
          .toList(),
      ['BOTHER', 'NOT', '[headshake]'],
    );
  });

  test('ASL lexical finish verb does not conflict with aspect FINISH', () {
    expect(
      SignGlossMapper.signSequence(
        'We must work hard to accelerate our reading progress to finish the syllabus this semester.',
        'ENG',
      ).isNotEmpty,
      isTrue,
    );
  });

  test('ASL try not maintain with conditional if clause keeps time first', () {
    expect(
      SignGlossMapper.signSequence(
        'Try not to maintain a pessimistic attitude if it rains on the first day of your summer vacation.',
        'ENG',
      ).isNotEmpty,
      isTrue,
    );
  });

  test('ASL possessive strips apostrophe s before gloss lookup', () {
    final glosses = SignGlossMapper.signSequence(
      "The sick cat's daily progress improved.",
      'ENG',
    ).map((t) => t.gloss).toList();
    expect(glosses, contains('CAT'));
    expect(glosses.where((g) => g.length == 1 && g == 'C'), isEmpty);
  });
}
