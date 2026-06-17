/// ASL grammar references used by [SignGrammarEngine]:
///
/// - Time + Topic + Comment: [Germanna ASL Grammar Guide](https://germanna.edu/sites/default/files/2023-07/ASL%20Grammar%20Guide%20%28edit%207-24-23%29.pdf)
/// - Topic–Comment & gloss conventions: [ASLdeafined grammar guide](https://blog.asldeafined.com/2026/03/complete-guide-to-asl-grammar-rules-gloss-symbols/)
/// - Time / FINISH aspect: [Kent State ASL linguistics](https://www.kent.edu/mcls/translation-ma/blog/asl-linguistics-understanding-grammar-and-structure-american-sign-language)
/// - Sign order & topicalization: [LifePrint ASL grammar](https://lifeprint.com/asl101/pages-layout/grammar.htm)
/// - Name introductions (MY NAME / IX-me NAME): [HandsSpeak intro](https://www.handspeak.com/learn/117/), [LifePrint ME vs MY](https://lifeprint.com/asl101/topics/grammar-10.htm)
/// - Personal names fingerspelled after NAME sign: [HandsSpeak NAME](https://www.handspeak.com/word/1464/)
/// - Asking a name: YOUR NAME WHAT? ([Germanna](https://germanna.edu/sites/default/files/2023-07/ASL%20Grammar%20Guide%20%28edit%207-24-23%29.pdf), [HandsSpeak](https://www.handspeak.com/learn/117/))
/// - Demonstrative + noun: [LifePrint THIS](https://lifeprint.com/asl101/pages-signs/t/this.htm), [LifePrint topic-comment](https://lifeprint.com/asl101/topics/grammar5.htm)
/// - Yes/no questions: [LifePrint pronoun copy](https://www.lifeprint.com/asl101/topics/pronoun-copy-and-yes-no-sentences-in-asl.htm), [PocketSign](https://www.pocketsign.org/asl-grammar/non-manual-marker/yes-no-questions)
/// - Negation / imperatives: [Germanna](https://germanna.edu/sites/default/files/2023-07/ASL%20Grammar%20Guide%20%28edit%207-24-23%29.pdf), [HandsSpeak commands](https://www.handspeak.com/learn/195/)
/// - Greetings: [LifePrint HELLO](https://lifeprint.com/asl101/pages-signs/h/hello.htm), [HandsSpeak nice to meet you](https://www.handspeak.com/word/search/index.php?asl=nice+to+meet+you), [ASL Interactive greetings](https://www.aslinteractive.com/greetings)
/// - Rule of 9 (numerical incorporation): cardinals 1–9 fuse into temporal bases;
///   ≥10 stay as separate signs ([LifePrint numbers](https://lifeprint.com/asl101/topics/numbers.htm))
/// - FINISH aspect for completed actions without a time anchor
/// - Conjunction AND is omitted; lists use non-manual listing / body tilt
library;

import 'asl_core_lexicon.dart';

abstract final class AslGrammarRules {
  /// Greeting signs that may precede a name introduction clause.
  static const introductionGreetings = {'hi', 'hello'};

  /// Fixed-order greeting glosses after grammar-engine tokenization.
  static const greetingPhrases = <List<String>>[
    ['nice', 'meet', 'you'],
    ['good', 'morning'],
    ['good', 'afternoon'],
    ['good', 'evening'],
    ['good', 'night'],
    ['how', 'you'],
    ['see', 'you', 'later'],
    ['see', 'you'],
    ['good', 'see', 'you'],
  ];

  static bool isGreetingPhrase(List<String> words) {
    for (final phrase in greetingPhrases) {
      if (words.length != phrase.length) {
        continue;
      }
      var matches = true;
      for (var i = 0; i < phrase.length; i++) {
        if (words[i] != phrase[i]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
    return false;
  }

  static List<String>? greetingPhraseOrder(List<String> words) {
    for (final phrase in greetingPhrases) {
      if (words.length != phrase.length) {
        continue;
      }
      var matches = true;
      for (var i = 0; i < phrase.length; i++) {
        if (words[i] != phrase[i]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return List<String>.from(phrase);
      }
    }
    return null;
  }

  /// Possessive markers in MY/YOUR NAME introductions (not casual ME NAME).
  static const introductionPossessives = {'my', 'your'};

  /// Subject markers for casual introductions (I am … / IX-me …).
  static const introductionSubjects = {'my', 'me', 'your'};

  /// Time adverbs establish tense at the start of the clause (after future WILL).
  static const timeWords = {
    'today',
    'tomorrow',
    'yesterday',
    'now',
    'later',
    'soon',
    'morning',
    'afternoon',
    'evening',
    'tonight',
    'night',
    'week',
    'month',
    'year',
    'once',
    'twice',
    'again',
    'always',
    'sometimes',
    'often',
    'seldom',
    'never',
    'last',
    'next',
    'before',
    'after',
    'early',
    'late',
    'hour',
    'minute',
    'second',
    'day',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };

  /// WH-signs are sentence-final in ASL questions.
  static const questionWords = {
    'what',
    'who',
    'where',
    'when',
    'why',
    'how',
    'which',
  };

  static const subjectPronouns = {
    'me',
    'you',
    'my',
    'your',
    'our',
    'their',
    'we',
    'they',
    'ix',
  };

  static const grammarMarkers = {
    'not',
    'finish',
    'will',
  };

  static const commonVerbs = {
    'be',
    'check',
    'come',
    'do',
    'get',
    'give',
    'go',
    'have',
    ...AslCoreLexicon.curriculumVerbs,
  };

  static const adjectiveSuffixes = AslCoreLexicon.adjectiveSuffixes;
}
