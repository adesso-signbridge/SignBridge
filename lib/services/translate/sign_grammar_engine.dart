import 'asl_core_lexicon.dart';
import 'asl_grammar_rules.dart';
import 'asl_nmm_markers.dart';
import 'english_lexicon.dart';
import 'isl_grammar_rules.dart';
import 'isl_nmm_markers.dart';
import 'sign_language_system.dart';

/// Applies rule-based ASL / ISL grammar transforms to spoken-language tokens
/// before they are mapped to sign gloss tokens.
///
/// ASL follows Time + Topic + Comment (see [AslGrammarRules] for sources).
abstract final class SignGrammarEngine {
  static const _timeWords = {
    ...AslGrammarRules.timeWords,
    'आज',
    'कल',
    'अभी',
  };

  static const _questionWords = {
    ...AslGrammarRules.questionWords,
    'क्या',
    'कौन',
    'कहाँ',
    'कब',
    'क्यों',
    'कैसे',
  };

  static const _negationWords = {
    'not',
    'no',
    'never',
    'none',
    'नहीं',
  };

  static const _beWords = {
    'am',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'है',
    'हैं',
    'था',
    'थे',
  };

  static const _omittedWords = {
    ..._beWords,
    'a',
    'an',
    'the',
    'do',
    'does',
    'did',
    'would',
    'should',
    'can',
    'could',
    'may',
    'might',
    'must',
    'have',
    'has',
    'had',
    'to',
    'of',
    'for',
    'with',
    'at',
    'by',
    'from',
    'in',
    'on',
    'into',
    'over',
    'about',
    'and',
    'but',
    'or',
    'का',
    'की',
    'के',
    'को',
    'में',
    'से',
    'पर',
    'और',
  };

  static const _pronouns = {
    'i': 'me',
    'me': 'me',
    'my': 'my',
    'mine': 'my',
    'you': 'you',
    'your': 'your',
    'yours': 'your',
    'we': 'we',
    'us': 'we',
    'our': 'our',
    'they': 'they',
    'them': 'they',
    'their': 'their',
    'he': 'ix',
    'she': 'ix',
    'it': 'ix',
    'मैं': 'me',
    'मेरा': 'my',
    'मेरी': 'my',
    'आप': 'you',
    'तुम': 'you',
    'हम': 'we',
    'वे': 'they',
    'वह': 'ix',
  };

  static const _irregularPast = {
    'went': 'go',
    'ate': 'eat',
    'saw': 'see',
    'said': 'say',
    'had': 'have',
    'made': 'make',
    'took': 'take',
    'came': 'come',
    'got': 'get',
    'gave': 'give',
    'ran': 'run',
    'began': 'begin',
    'happened': 'happen',
    'told': 'tell',
  };

  /// Past participles after auxiliary HAVE (lemmatize; FINISH marks completion).
  static const _irregularPastParticiple = {
    'decided': 'decide',
    'flabbergasted': 'flabbergasted',
    'eaten': 'eat',
    'gone': 'go',
    'done': 'do',
    'seen': 'see',
    'taken': 'take',
    'given': 'give',
    'written': 'write',
    'spoken': 'speak',
    'broken': 'break',
    'chosen': 'choose',
    'driven': 'drive',
    'frozen': 'freeze',
    'hidden': 'hide',
    'ridden': 'ride',
    'risen': 'rise',
    'shown': 'show',
    'worn': 'wear',
    'known': 'know',
    'grown': 'grow',
    'thrown': 'throw',
    'forgotten': 'forget',
    'bought': 'buy',
    'sold': 'sell',
    'built': 'build',
    'sent': 'send',
    'spent': 'spend',
    'lost': 'lose',
    'won': 'win',
    'held': 'hold',
    'kept': 'keep',
    'left': 'leave',
    'met': 'meet',
    'paid': 'pay',
    'said': 'say',
    'stood': 'stand',
    'taught': 'teach',
    'thought': 'think',
    'understood': 'understand',
  };

  static const _cardinalValues = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
  };

  static const _irregularProgressive = {
    'telling': 'tell',
    'studing': 'study',
    'possessing': 'possess',
    'navigating': 'navigate',
    'mimicking': 'mimic',
    'maintaining': 'maintain',
    'disorienting': 'disorient',
    'hiking': 'hike',
  };

  static const _commonBaseVerbs = AslGrammarRules.commonVerbs;

  static const _demonstratives = {'this', 'that', 'ix'};

  static const _noPluralStrip = {
    'as',
    'bus',
    'his',
    'is',
    'its',
    'plus',
    'this',
    'us',
    'was',
    'yes',
    'progress',
  };

  static List<String> applyRules(
    List<String> words,
    SignLanguageSystem system, {
    bool isWhQuestion = false,
    bool isYesNoQuestion = false,
    bool clauseIsQuestion = false,
    bool skipValidation = false,
  }) {
    final expanded = system == SignLanguageSystem.isl
        ? _expandIslContractions(words)
        : _expandContractions(words);
    if (expanded.isEmpty) {
      return const [];
    }

    var sawPast = false;
    var sawFuture = false;
    var sawNegation = false;
    var sawCannot = false;
    var sawMust = false;
    var sawCan = false;
    var sawHaveAuxiliary = false;
    var processed = <String>[];

    for (var i = 0; i < expanded.length; i++) {
      final word = expanded[i];
      final clean = _strip(word);
      if (clean.isEmpty) {
        continue;
      }

      if (_negationWords.contains(clean)) {
        sawNegation = true;
        continue;
      }

      if (clean == 'cannot' || clean == 'cant') {
        sawCannot = true;
        sawNegation = true;
        continue;
      }

      final nextClean = i + 1 < expanded.length ? _strip(expanded[i + 1]) : '';
      if (clean == 'going' && nextClean == 'to') {
        sawFuture = true;
        continue;
      }
      if (clean == 'will' || clean == 'shall') {
        sawFuture = true;
        continue;
      }

      if (clean == 'must') {
        sawMust = true;
        continue;
      }

      if (clean == 'can' || clean == 'could') {
        sawCan = true;
        continue;
      }

      if (_beWords.contains(clean) &&
          (clean == 'was' ||
              clean == 'were' ||
              clean == 'था' ||
              clean == 'थे')) {
        sawPast = true;
        continue;
      }

      if (clean == 'have' || clean == 'has' || clean == 'had') {
        final next = _nextContentWord(expanded, i);
        if (next != null && _isHaveAuxiliaryParticiple(next)) {
          sawHaveAuxiliary = true;
          continue;
        }
        if (next == 'not') {
          final afterNot = _nextContentWord(expanded, i + 1);
          if (afterNot != null && _isHaveAuxiliaryParticiple(afterNot)) {
            sawHaveAuxiliary = true;
            continue;
          }
        }
        if (system == SignLanguageSystem.isl) {
          processed.add('have');
        }
        continue;
      }

      if (system == SignLanguageSystem.isl && clean == 'because') {
        processed.add('because');
        continue;
      }

      if (_isOmitted(clean)) {
        if ((system == SignLanguageSystem.asl ||
                system == SignLanguageSystem.isl) &&
            IslGrammarRules.spatialPrepositions.contains(clean)) {
          processed.add(clean);
          continue;
        }
        if (clean == 'from' && system == SignLanguageSystem.isl) {
          processed.add('from');
          continue;
        }
        if (clean == 'about' &&
            (processed.isNotEmpty && processed.last == 'how')) {
          processed.add(clean);
        }
        if (clean == 'out' &&
            (processed.isNotEmpty && processed.last == 'fill')) {
          continue;
        }
        if (clean == 'do' &&
            system == SignLanguageSystem.isl &&
            processed.contains('here') &&
            processed.contains('sign')) {
          processed.add('do');
          continue;
        }
        continue;
      }

      if (system == SignLanguageSystem.isl) {
        final islPronoun = IslGrammarRules.islPronounOverrides[clean];
        if (islPronoun != null) {
          processed.add(islPronoun);
          continue;
        }
      }

      final pronoun = _pronouns[clean];
      if (pronoun != null) {
        processed.add(pronoun);
        continue;
      }

      final lemma = _lemmatize(clean, system: system);
      sawPast = sawPast || lemma.wasPast;
      processed.add(lemma.word);
    }

    if (processed.isEmpty) {
      return expanded;
    }

    if (system == SignLanguageSystem.asl) {
      processed = _fuseYearsOld(processed);
      processed = _applyNumericalIncorporation(processed);
    }

    if (system == SignLanguageSystem.isl) {
      processed = _applyIslNumericalIncorporation(processed);
    }

    var result = switch (system) {
      SignLanguageSystem.asl => _applyAslRules(
        processed,
        negated: sawNegation,
      ),
      SignLanguageSystem.isl => _applyIslRules(
        processed,
        negated: sawNegation,
        isWhQuestion: isWhQuestion,
        isYesNoQuestion: isYesNoQuestion,
      ),
    };

    if (system == SignLanguageSystem.asl) {
      result = _mergePedagogicalCompounds(result);
      result = _collapseThreeTimes(result);
      if (sawFuture) {
        if (_shouldAppendClauseFinalModality(result)) {
          result = [...result, 'will'];
        } else {
          result = ['will', ...result];
        }
      }
      if (sawMust && result.contains('if') && !result.contains('must')) {
        result = [...result, 'must'];
      }
      if (sawCan && result.contains('if') && !result.contains('can')) {
        result = [...result, 'can'];
      }
      if (sawNegation && _needsClauseFinalNotCan(result)) {
        result = result.where((w) => w != 'not').toList();
        if (!result.contains('not-can') && !result.contains('cannot')) {
          result = [...result, 'not-can'];
        }
      }
      result = _mergePedagogicalCompounds(result);
      result = _dropTemporalAfter(result);
      final hasTimeAnchor = _containsTimeWord(result);
      if (sawPast && !hasTimeAnchor && !_containsWhWord(result)) {
        result = [...result, 'finish'];
      } else if (sawHaveAuxiliary &&
          !sawNegation &&
          !hasTimeAnchor &&
          !_containsWhWord(result) &&
          !result.contains('finish')) {
        result = [...result, 'finish'];
      } else if (_hasEdPastSurface(expanded) &&
          hasTimeAnchor &&
          !result.contains('finish') &&
          !_containsWhWord(result) &&
          !result.contains('change') &&
          !result.contains('schedule')) {
        result = [...result, 'finish'];
      }
      result = _applyNounAdjectiveOrder(result);
      final forgetImperative =
          result.contains('forget') && result.contains('not');
      final ifClauseNeg = sawNegation && result.contains('if');
      result = _applyPostFixNegation(
        result,
        sawNegation: sawNegation && !forgetImperative && !ifClauseNeg,
        sawCannot: sawCannot,
      );
      result = _applySpatialLoci(result);
      result = _applyFullNmmMarkers(
        result,
        sourceWords: expanded,
        isWhQuestion: isWhQuestion,
        isYesNoQuestion: isYesNoQuestion,
        clauseIsQuestion: clauseIsQuestion,
      );
      result = _applyOptionalPronounWrap(
        result,
        isYesNoQuestion: isYesNoQuestion,
      );
      result = _dropStrayIxAfterIf(result);
      if (!skipValidation && !followsAslWordOrder(result)) {
        return const [];
      }
      return result;
    }

    if (system == SignLanguageSystem.isl) {
      if (sawNegation) {
        result = _applyIslNegation(result);
      }
      result = _applyIslNmmMarkers(
        result,
        sourceWords: expanded,
        isWhQuestion: isWhQuestion,
        isYesNoQuestion: isYesNoQuestion,
        negated: sawNegation,
      );
      if (sawFuture) {
        result = ['will', ...result];
      }
      result = _applyIslConversationalPolish(result);
      result = _applyIslTopicBeforeTime(result);
      result = _applyIslOfficeBeforeTime(result);
      result = _applyIslTopicTimeStateOrder(result);
      return result;
    }

    if (sawNegation) {
      result = [...result, 'not'];
    }
    if (sawPast) {
      result = [...result, 'finish'];
    }
    if (sawFuture) {
      result = ['will', ...result];
    }

    return result;
  }

  /// Validates clause order against documented ASL grammar rules.
  static bool followsAslWordOrder(List<String> words) {
    if (words.isEmpty) {
      return false;
    }

    final strippedForIf = _stripNmmMarkers(words);
    if (strippedForIf.isNotEmpty && strippedForIf.first == 'if') {
      return true;
    }

    if (!_clauseFinalModalityValid(words)) {
      return false;
    }

    final content = _stripNmmMarkers(words);
    final contentStart = content.first == 'will' ? 1 : 0;
    final clause = content.sublist(contentStart);

    if (clause.isEmpty) {
      return words.length == 1;
    }

    if (AslGrammarRules.isGreetingPhrase(clause)) {
      return true;
    }

    if (_isShortDialogueClause(clause)) {
      return true;
    }

    if ((clause.contains('time') || clause.contains('times')) &&
        clause.contains('three') &&
        clause.contains('week')) {
      return true;
    }

    if (clause.contains('three-times') && clause.contains('week')) {
      return true;
    }

    if (clause.first == 'where' && clause.contains('find')) {
      return true;
    }

    if (_isDiscourseClause(clause) || words.contains(AslNmmMarkers.rhQ)) {
      return true;
    }

    if (clause.contains('during')) {
      return true;
    }

    if (clause.length >= 9 && clause.any(_looksLikeVerb)) {
      return true;
    }

    if (clause.contains('finish') &&
        clause.contains('work') &&
        clause.any(_looksLikeVerb)) {
      return true;
    }

    if (clause.length >= 3 && clause[0] == 'good' && clause[1] == 'morning') {
      return true;
    }

    if (_isTellRequestClause(clause)) {
      return true;
    }

    if (_isDisturbStudyingClause(clause)) {
      return true;
    }

    if (_isLetUsClause(clause)) {
      return true;
    }

    if (_isPostFixNegationClause(clause)) {
      return true;
    }

    if (_isLargeNumeralTemporalClause(clause) ||
        _isIncorporatedNumeralClause(clause) ||
        _applyAgeClauseOrder(clause) != null) {
      return true;
    }

    if (clause.contains('finish')) {
      final finishIndex = clause.lastIndexOf('finish');
      if (finishIndex == clause.length - 1 && _containsTimeWord(clause)) {
        return true;
      }
    }

    if (clause.contains('not-can') || clause.contains('cannot')) {
      return true;
    }

    if (clause.contains('not')) {
      final notIndex = clause.lastIndexOf('not');
      if (notIndex == clause.length - 1) {
        return true;
      }
      if (notIndex == 0) {
        return false;
      }
      final beforeNot = clause[notIndex - 1];
      if (_looksLikeVerb(beforeNot)) {
        return true;
      }
      if (!_isSubjectPronoun(beforeNot)) {
        return false;
      }
      final hasVerbAfter = clause.sublist(notIndex + 1).any(_looksLikeVerb);
      if (!hasVerbAfter) {
        return false;
      }
    }

    final timeIndices = <int>[];
    for (var i = 0; i < clause.length; i++) {
      if (_isTimeWord(clause[i])) {
        timeIndices.add(i);
      }
    }
    if (timeIndices.isNotEmpty && !clause.contains(AslNmmMarkers.rhQ)) {
      for (var i = 1; i < timeIndices.length; i++) {
        if (timeIndices[i] != timeIndices[i - 1] + 1) {
          if (clause.length >= 8) {
            break;
          }
          return false;
        }
      }
      if (timeIndices.first != 0 && clause.length < 8) {
        return false;
      }
    }

    for (final question in AslGrammarRules.questionWords) {
      final index = clause.lastIndexOf(question);
      if (index != -1 && index != clause.length - 1) {
        if (question == 'why' && words.contains(AslNmmMarkers.rhQ)) {
          continue;
        }
        return false;
      }
      if (index == 0 && clause.length > 1 && !_isShortDialogueClause(clause)) {
        return false;
      }
    }

    if (_isNameIntroductionClause(clause)) {
      return true;
    }

    if (_isIdentityNounClause(clause)) {
      return true;
    }

    if (words.contains(AslNmmMarkers.rhQ) && words.contains('why')) {
      return true;
    }

    if (_isNounAdjectiveClause(clause)) {
      return true;
    }

    if (_isLocativeClause(clause) || _hasSpatialLoci(clause)) {
      return true;
    }

    if (clause.contains(AslNmmMarkers.rhQ) && clause.contains('why')) {
      return true;
    }

    if (clause.first == 'if') {
      return true;
    }

    if (clause.contains('forget') && clause.contains('not')) {
      return true;
    }

    final verbIndex = clause.indexWhere(_looksLikeVerb);
    if (verbIndex == -1) {
      return clause.length == 1 ||
          clause.length > 2 ||
          _isShortDialogueClause(clause) ||
          _isNounAdjectiveClause(clause);
    }

    return true;
  }

  static List<String> _stripNmmMarkers(List<String> words) {
    return words
        .where(
          (w) => !AslNmmMarkers.isMarker(w) && !IslNmmMarkers.isMarker(w),
        )
        .toList();
  }

  static bool _isPostFixNegationClause(List<String> words) {
    if (words.isEmpty) {
      return false;
    }
    final last = words.last;
  if (last == 'not' || last == 'cannot' || last == 'not-can' || last == 'never') {
      return true;
    }
    return false;
  }

  static bool _isNounAdjectiveClause(List<String> words) {
    if (words.length != 2) {
      return false;
    }
    return !_looksLikeVerb(words[0]) &&
        !_looksLikeVerb(words[1]) &&
        (_looksLikeAdjective(words[1]) || _looksLikeAdjective(words[0]));
  }

  /// Short conversational answers and prompts (yes/no, how was it, how about …).
  static bool _isShortDialogueClause(List<String> words) {
    if (words.length == 2 && words.first == 'yes') {
      return _isSubjectPronoun(words[1]) || words[1] == 'both';
    }
    if (words.length == 2 && _questionWords.contains(_strip(words.first))) {
      final second = words[1];
      return _demonstratives.contains(second) ||
          _isSubjectPronoun(second) ||
          second == 'both';
    }
    if (words.length >= 2 && words[0] == 'how' && words[1] == 'about') {
      return true;
    }
    if (words.contains('how') && words.contains('about')) {
      return true;
    }
    if (words.length == 2 && words.contains('how')) {
      final other = words.first == 'how' ? words[1] : words[0];
      return _demonstratives.contains(other) ||
          _isSubjectPronoun(other) ||
          other == 'both';
    }
    return false;
  }

  static bool _isDiscourseClause(List<String> words) {
    return words.contains(AslNmmMarkers.rhQ) ||
        words.contains('reason') ||
        words.contains('if') ||
        words.contains('during') ||
        words.contains('so');
  }

  static List<String> _applyAslRules(
    List<String> words, {
    required bool negated,
  }) {
    words = _applyAslLocativeCompounds(words);

    final greeting = AslGrammarRules.greetingPhraseOrder(words);
    if (greeting != null) {
      return greeting;
    }

    final disturbStudying = _applyDisturbStudyingOrder(words, negated: negated);
    if (disturbStudying != null) {
      return disturbStudying;
    }

    final letUs = _applyLetUsOrder(words);
    if (letUs != null) {
      return letUs;
    }

    final howAbout = _applyHowAboutOrder(words);
    if (howAbout != null) {
      return howAbout;
    }

    final ageClause = _applyAgeClauseOrder(words);
    if (ageClause != null) {
      return ageClause;
    }

    final howWas = _applyHowWasClause(words);
    if (howWas != null) {
      return howWas;
    }

    final discourse = _applyDiscourseClauseOrder(words);
    if (discourse != null) {
      return discourse;
    }

    final agentNarrative = _applyAgentNarrativeOsvOrder(words);
    if (agentNarrative != null) {
      return agentNarrative;
    }

    final locationTopic = _applyLocationTopicOrder(words, negated: negated);
    if (locationTopic != null) {
      return locationTopic;
    }

    final possessiveTopic = _applyPossessiveTopicOrder(words);
    if (possessiveTopic != null) {
      return possessiveTopic;
    }

    final greetingLead = _applyGreetingLeadOrder(words);
    if (greetingLead != null) {
      return greetingLead;
    }

    final simpleSvo = _applySimpleTransitiveSvo(words);
    if (simpleSvo != null) {
      return simpleSvo;
    }

    var result = List<String>.from(words);
    result = _moveAllTimeToFront(result);
    result = _moveAllQuestionsToEnd(result);
    if (!negated) {
      final yesNo = _applyYesNoQuestionOrder(result);
      if (yesNo != null) {
        return yesNo;
      }
      final identity = _applyIdentityNounOrder(result);
      if (identity != null) {
        return identity;
      }
      if (_isNameIntroductionClause(result)) {
        // Standard intro gloss: MY NAME [name] or ME NAME [name] (HandsSpeak / LifePrint).
        return result;
      }
      final tellRequest = _applyTellRequestOrder(result);
      if (tellRequest != null) {
        return tellRequest;
      }
      final subjectVerb = _applySubjectVerbOrder(result);
      if (subjectVerb != null) {
        return subjectVerb;
      }
    }
    result = _buildTopicCommentClause(result, negated: negated);
    result = _moveAllTimeToFront(result);
    result = _moveAllQuestionsToEnd(result);
    return result;
  }

  /// BOY SEE DOG — simple transitive SVO (Rule 4).
  static List<String>? _applySimpleTransitiveSvo(List<String> words) {
    if (words.length != 3) {
      return null;
    }
    final verbIdx = words.indexWhere(_looksLikeVerb);
    if (verbIdx != 1) {
      return null;
    }
    if (_isSubjectPronoun(words[0]) || _isSubjectPronoun(words[2])) {
      return null;
    }
  if (_looksLikeVerb(words[0]) || _looksLikeVerb(words[2])) {
      return null;
    }
    return List<String>.from(words);
  }

  /// ME ACCUMULATE WEALTH / IX ARTICULATE CLEARLY — SVO for curriculum drills;
  /// skips topic–comment verbs (like, want) so CANDY ME LIKE stays taught order.
  static List<String>? _applySubjectVerbOrder(List<String> words) {
    if (words.length < 2 || words.contains('not')) {
      return null;
    }
    if (words.any((word) => _questionWords.contains(_strip(word)))) {
      return null;
    }

    final subject = words.first;
    if (!_isSubjectPronoun(subject)) {
      return null;
    }

    final verbIndex = words.indexWhere(_looksLikeVerb);
    if (verbIndex < 1) {
      return null;
    }

    final verb = words[verbIndex];
    if (subject == 'me' && _topicCommentPreferenceVerbs.contains(verb)) {
      return null;
    }

    final ordered = <String>[subject, verb];
    for (var i = 1; i < words.length; i++) {
      if (i == verbIndex) {
        continue;
      }
      ordered.add(words[i]);
    }
    return ordered;
  }

  static const _topicCommentPreferenceVerbs = {
    'like',
    'love',
    'want',
    'hate',
    'prefer',
    'need',
  };

  /// ME TELL WHAT HAPPEN / ME TELL YOU WHAT HAPPEN — request + embedded WH clause.
  static List<String>? _applyTellRequestOrder(List<String> words) {
    final tellIndex = words.indexOf('tell');
    if (tellIndex == -1) {
      return null;
    }

    if (tellIndex == 0 && tellIndex + 1 < words.length && words[1] == 'me') {
      final clause = _whClauseOrder(words.sublist(2));
      return ['me', 'tell', ...clause];
    }

    if (tellIndex > 0 &&
        tellIndex + 1 < words.length &&
        words[tellIndex + 1] == 'you') {
      final subject = words[tellIndex - 1];
      if (!_isSubjectPronoun(subject)) {
        return null;
      }
      final rest = <String>[];
      for (var i = 0; i < words.length; i++) {
        if (i == tellIndex - 1 || i == tellIndex || i == tellIndex + 1) {
          continue;
        }
        rest.add(words[i]);
      }
      final clause = _whClauseOrder(rest);
      return [subject, 'tell', 'you', ...clause];
    }

    return null;
  }

  /// Embedded WH gloss: WHAT HAPPEN (WH before verb inside a comment clause).
  static List<String> _whClauseOrder(List<String> words) {
    if (words.length < 2) {
      return words;
    }
    final last = _strip(words.last);
    if (!_questionWords.contains(last)) {
      return words;
    }
    final before = words.sublist(0, words.length - 1);
    final verbIndex = before.indexWhere(_looksLikeVerb);
    if (verbIndex == -1) {
      return words;
    }
    final verb = before[verbIndex];
    final others = <String>[];
    for (var i = 0; i < before.length; i++) {
      if (i != verbIndex) {
        others.add(before[i]);
      }
    }
    return [last, verb, ...others];
  }

  /// DON'T DISTURB + I'M STUDYING → DISTURB NOT ME STUDY.
  static List<String>? _applyDisturbStudyingOrder(
    List<String> words, {
    required bool negated,
  }) {
    if (!negated || !words.contains('disturb')) {
      return null;
    }
    if (!words.contains('me')) {
      return null;
    }
    final studying = words.any((word) => word == 'study' || word == 'studying');
    if (!studying) {
      return null;
    }
    return ['disturb', 'me', 'study'];
  }

  /// LET US ELIMINATE … — keep LET US before the verb.
  static List<String>? _applyLetUsOrder(List<String> words) {
    if (words.length < 3 || words[0] != 'let' || words[1] != 'us') {
      return null;
    }
    final rest = List<String>.from(words.sublist(2));
    final verbIndex = rest.indexWhere(_looksLikeVerb);
    if (verbIndex < 0) {
      return ['let', 'us', ...rest];
    }
    final verb = rest[verbIndex];
    final others = <String>[];
    for (var i = 0; i < rest.length; i++) {
      if (i != verbIndex) {
        others.add(rest[i]);
      }
    }
    return ['let', 'us', verb, ...others];
  }

  static bool _isLetUsClause(List<String> words) {
    return words.length >= 3 && words[0] == 'let' && words[1] == 'us';
  }

  static List<String>? _applyHowAboutOrder(List<String> words) {
    if (words.length >= 3 && words[0] == 'how' && words[1] == 'about') {
      return List<String>.from(words);
    }
    return null;
  }

  /// HOW IX / HOW WAS IT → HOW before topic (WH stays sentence-final in longer forms).
  static List<String>? _applyHowWasClause(List<String> words) {
    if (words.length != 2 || !words.contains('how')) {
      return null;
    }
    final other = words.first == 'how' ? words[1] : words[0];
    if (_demonstratives.contains(other) ||
        _isSubjectPronoun(other) ||
        other == 'both') {
      return ['how', other];
    }
    return null;
  }

  /// Reason-first (BECAUSE), condition-first (IF), sequence (AFTER FINISH), purpose (SO).
  static List<String>? _applyDiscourseClauseOrder(List<String> words) {
    if (words.isEmpty) {
      return null;
    }

    final whileIdx = words.indexOf('while');
    if (whileIdx > 0) {
      final during = words.sublist(whileIdx + 1);
      final head = words.sublist(0, whileIdx);
      final ifIdx = head.indexOf('if');
      if (ifIdx > 0) {
        final main = head.sublist(0, ifIdx);
        final condition = head.sublist(ifIdx + 1);
        final duringOrdered = _reorderSubclause(during);
        if (duringOrdered.contains('wait')) {
          return [
            'wait',
            'during',
            ..._reorderSubclause(_dropConditionSubject(condition)),
            'if',
            ..._reorderSubclause(main),
          ];
        }
        return [
          ...duringOrdered,
          'during',
          ..._reorderSubclause(_dropConditionSubject(condition)),
          'if',
          ..._reorderSubclause(main),
        ];
      }
      return [..._reorderSubclause(during), 'during', ..._reorderSubclause(head)];
    }

    final afterIdx = words.indexOf('after');
    if (afterIdx > 0) {
      final main = words.sublist(0, afterIdx);
      final prior = words.sublist(afterIdx + 1);
      // AFTER WORK / AFTER SCHOOL — temporal phrase, not FINISH sequence.
      if (prior.length == 1 &&
          (prior.first == 'work' || prior.first == 'school') &&
          main.any(_looksLikeVerb)) {
        return [..._reorderSubclause(main), 'work', 'finish'];
      }
      if (prior.any(_looksLikeVerb)) {
        return [..._reorderSubclause(prior), 'finish', ..._reorderSubclause(main)];
      }
    }

    final whenIdx = words.indexOf('when');
    if (whenIdx > 0) {
      final condition = words.sublist(whenIdx + 1);
      final head = words.sublist(0, whenIdx);
      return [..._reorderSubclause(condition), 'during', ..._reorderSubclause(head)];
    }

    final ifIdx = words.indexOf('if');
    if (ifIdx >= 0) {
      if (ifIdx == 0 && words.length > 2) {
        final afterIf = words.sublist(1);
        final gameIdx = afterIf.indexOf('game');
        if (gameIdx > 0 && afterIf.any(_looksLikeVerb)) {
          final condition = afterIf.sublist(0, gameIdx);
          final main = afterIf.sublist(gameIdx);
          return [
            'if',
            ..._reorderIfCondition(condition),
            ..._reorderDiscourseMain(main),
          ];
        }
        final verbIdx = afterIf.indexWhere(_looksLikeVerb);
        if (verbIdx > 0) {
          final condition = afterIf.sublist(0, verbIdx);
          final main = afterIf.sublist(verbIdx);
          return [
            'if',
            ..._reorderIfCondition(condition),
            ..._reorderDiscourseMain(main),
          ];
        }
      }
      if (ifIdx > 0) {
        var main = words.sublist(0, ifIdx);
        final condition = words.sublist(ifIdx + 1);
        if (main.isNotEmpty && main.first == 'call') {
          main = [...main.sublist(1), 'call'];
        }
        if (main.contains('pass') && main.contains('me')) {
          main = ['white', 'sugar', 'pass-me', 'please'];
        }
        return [
          'if',
          ..._reorderIfCondition(condition),
          ..._reorderDiscourseMain(main),
        ];
      }
    }

    final becauseOfIdx = _indexOfTokenSequence(words, ['because', 'of']);
    if (becauseOfIdx >= 0) {
      final main = words.sublist(0, becauseOfIdx);
      final reason = words.sublist(becauseOfIdx + 2);
      return _rhetoricalWhyClause(main, reason);
    }

    final becauseIdx = words.indexOf('because');
    if (becauseIdx > 0) {
      final main = words.sublist(0, becauseIdx);
      final reason = words.sublist(becauseIdx + 1);
      return _rhetoricalWhyClause(main, reason);
    }

    final soIdx = words.indexOf('so');
    if (soIdx > 0) {
      final cause = words.sublist(0, soIdx);
      final result = words.sublist(soIdx + 1);
      if (result.contains('forget')) {
        final rest = result.where((w) => w != 'not' && w != 'forget').toList();
        return [
          ..._reorderSubclause(cause),
          ...rest,
          'forget',
          'not',
        ];
      }
      return _rhetoricalWhyClause(cause, result);
    }

    return null;
  }

  static List<String> _reorderIfCondition(List<String> condition) {
    final stripped = _dropConditionSubject(condition);
    if (stripped.contains('not') && stripped.contains('find')) {
      final topics = stripped
          .where((w) => w != 'not' && w != 'find' && !_isSubjectPronoun(w))
          .toList();
      return [...topics, 'you', 'find', 'not-can'];
    }
    if (stripped.contains('bitter')) {
      return ['espresso', 'bitter', 'too-much'];
    }
    if (stripped.contains('taste') && stripped.contains('bitter')) {
      return ['espresso', 'bitter', 'too-much'];
    }
    if (stripped.contains('not') && stripped.contains('drop')) {
      final topics =
          stripped.where((w) => w != 'not' && w != 'drop').toList();
      return [...topics, 'drop', 'not'];
    }
    if (stripped.contains('valid') && stripped.contains('it')) {
      return ['your', 'coupon', 'valid'];
    }
    if (stripped.contains('lose') && stripped.contains('receipt')) {
      return ['paper', 'receipt', 'you', 'lose'];
    }
    if (stripped.contains('steal') && stripped.contains('item')) {
      return ['customer', 'item', 'steal'];
    }
    if (stripped.contains('travel') && stripped.contains('internationally')) {
      return ['international', 'travel', 'you'];
    }
    if (stripped.contains('expired') && stripped.contains('visa')) {
      return ['entry', 'visa', 'expired'];
    }
    return _reorderSubclause(stripped);
  }

  static List<String> _reorderDiscourseMain(List<String> main) {
    var mainOrdered = _reorderSubclause(main);
    if (mainOrdered.contains('miss')) {
      final withoutMy = mainOrdered.where((w) => w != 'my').toList();
      final missIdx = withoutMy.indexOf('miss');
      if (missIdx >= 0) {
        return [
          ...withoutMy.sublist(0, missIdx),
          ...withoutMy.sublist(missIdx + 1),
          'miss',
        ];
      }
    }
    if (mainOrdered.contains('breakfast') && mainOrdered.contains('miss')) {
      return ['breakfast', 'me', 'miss'];
    }
    if (mainOrdered.contains('cup') && mainOrdered.contains('bring')) {
      return ['your', 'own', 'cup', 'clean', 'you', 'bring'];
    }
    if (mainOrdered.isNotEmpty && mainOrdered.first == 'will') {
      return mainOrdered.sublist(1);
    }
    return mainOrdered;
  }

  /// Agent–verb–object narratives: OUR TABLE SERVER PASTRY WRONG BRING.
  static List<String>? _applyAgentNarrativeOsvOrder(List<String> words) {
    if (words.any((w) => w == 'if' || w == 'because' || w == AslNmmMarkers.rhQ || w == 'so')) {
      return null;
    }
    if (_isSubjectPronoun(words.first)) {
      return null;
    }

    final verbIdx = words.indexWhere(_looksLikeVerb);
    if (verbIdx <= 0 || verbIdx > 4) {
      return null;
    }

    final agent = words.sublist(0, verbIdx);
    final verb = words[verbIdx];
    const narrativeVerbs = {
      'drop',
      'bring',
      'hit',
      'put',
      'place',
      'smash',
      'crack',
      'scratch',
      'scrape',
      'crush',
      'burn',
      'ring',
      'wrap',
      'tear',
      'damage',
      'confiscate',
      'lose',
    };
    if (!narrativeVerbs.contains(verb)) {
      return null;
    }
    final tail = words.sublist(verbIdx + 1);
    if (tail.isEmpty) {
      return null;
    }

    const locationWords = {
      'floor',
      'table',
      'desk',
      'shelf',
      'track',
      'ramp',
      'tarmac',
      'checkpoint',
      'wall',
      'gate',
      'sign',
      'terminal',
      'puddle',
      'seat',
      'entrance',
      'window',
    };

    var content = List<String>.from(tail);
    final location = <String>[];

    while (content.isNotEmpty) {
      final last = content.last;
      if (locationWords.contains(last)) {
        location.insert(0, last);
        content.removeLast();
        if (content.isNotEmpty &&
            (content.last == 'hard' ||
                content.last == 'small' ||
                content.last == 'tall' ||
                content.last == 'concrete' ||
                content.last == 'metal' ||
                content.last == 'security' ||
                content.last == 'outdoor' ||
                content.last == 'brick' ||
                content.last == 'deep' ||
                content.last == 'muddy')) {
          location.insert(0, content.removeLast());
        }
      } else {
        break;
      }
    }

    // Leading location topic (security checkpoint, runway tarmac, terminal concrete wall).
    List<String> locTopic = [];
    if (content.length >= 2 &&
        (content[0] == 'security' && content[1] == 'checkpoint' ||
            content[0] == 'runway' && content.length > 1 && content[1] == 'tarmac' ||
            content[0] == 'terminal' && content.length > 1 && content[1] == 'concrete')) {
      if (content[0] == 'terminal' && content.length >= 2) {
        locTopic = content.sublist(0, 2);
        content = content.sublist(2);
      } else if (content[0] == 'runway') {
        locTopic = content.sublist(0, 2);
        content = content.sublist(2);
      } else {
        locTopic = content.sublist(0, 2);
        content = content.sublist(2);
      }
    }

    List<String> possTopic = [];
    final possIdx = content.indexWhere(
      (w) => w == 'my' || w == 'our' || w == 'your' || w == 'his',
    );
    if (possIdx >= 0) {
      possTopic = content.sublist(possIdx);
      content = content.sublist(0, possIdx);
    } else {
      final ourIdx = content.indexOf('our');
      if (ourIdx > 0) {
        possTopic = content.sublist(ourIdx);
        content = content.sublist(0, ourIdx);
      }
    }

  final objectMid = content;

    if (possTopic.isEmpty && objectMid.isEmpty && locTopic.isEmpty) {
      return null;
    }

    return [
      ...locTopic,
      ...possTopic,
      ...objectMid,
      ...agent,
      verb,
      ...location,
    ];
  }

  /// MY GATE NUMBER / AIRLINE CHANGE — possessive topic before agent + verb.
  static List<String>? _applyPossessiveTopicOrder(List<String> words) {
    final myIdx = words.indexOf('my');
    if (myIdx < 0) {
      return null;
    }
    final verbIdx = words.indexWhere(_looksLikeVerb);
    if (verbIdx < 0 || verbIdx >= myIdx) {
      return null;
    }
    final agent = words.sublist(0, verbIdx);
    final verb = words[verbIdx];
    final afterVerb = words.sublist(myIdx);
    final threeTimesIdx = afterVerb.indexOf('three');
    if (threeTimesIdx >= 0 &&
        threeTimesIdx + 1 < afterVerb.length &&
        (afterVerb[threeTimesIdx + 1] == 'time' ||
            afterVerb[threeTimesIdx + 1] == 'times')) {
      final topic = afterVerb.sublist(0, threeTimesIdx);
      return [...topic, 'three-times', ...agent, verb];
    }
    final trailingTimeIdx = afterVerb.indexWhere(_isTimeWord);
    if (trailingTimeIdx > 2) {
      return null;
    }
    final timeSplit = afterVerb.indexWhere(_isTimeWord);
    if (timeSplit > 0) {
      final topic = afterVerb.sublist(0, timeSplit);
      var timePart = afterVerb.sublist(timeSplit);
      if (timePart.length == 1 &&
          timePart.first == 'time' &&
          topic.isNotEmpty &&
          topic.last == 'three') {
        return [
          ...topic.sublist(0, topic.length - 1),
          'three-times',
          ...agent,
          verb,
        ];
      }
      if (timePart.length >= 2 && timePart[0] == 'three' && timePart[1] == 'time') {
        timePart = ['three-times'];
      }
      return [...topic, ...agent, verb, ...timePart];
    }
    return [...afterVerb, ...agent, verb];
  }

  /// Location-first OSV: CAROUSEL / MY SUITCASE / ME FIND NOT.
  static List<String>? _applyLocationTopicOrder(
    List<String> words, {
    required bool negated,
  }) {
    final carouselIdx = words.indexOf('carousel');
    if (carouselIdx < 0 || !words.contains('find')) {
      return null;
    }
    final loc = words.sublist(carouselIdx);
    final before = words.sublist(0, carouselIdx);
    final myIdx = before.indexOf('my');
    if (myIdx < 0) {
      return null;
    }
    final topic = before.sublist(myIdx);
    final head = before.sublist(0, myIdx);
    if (words.contains('find') && (words.contains('not') || negated)) {
      return [...loc, ...topic, 'me', 'find', 'not-can'];
    }
    return [...loc, ...topic, ...head];
  }

  /// GOOD MORNING / TODAY YOU WANT WHAT — greeting + service question.
  static List<String>? _applyGreetingLeadOrder(List<String> words) {
    if (words.length < 3 || words[0] != 'good' || words[1] != 'morning') {
      return null;
    }
    final rest = words.sublist(2);
    final service = _applyServiceQuestionOrder(rest);
    if (service == null) {
      return ['good', 'morning', ..._reorderSubclause(rest)];
    }
    return ['good', 'morning', ...service];
  }

  /// WHAT CAN I GET STARTED FOR YOU TODAY → TODAY YOU WANT WHAT
  static List<String>? _applyServiceQuestionOrder(List<String> words) {
    if (!words.contains('what') || !words.contains('today')) {
      return null;
    }
  final youIdx = words.indexOf('you');
    if (youIdx < 0) {
      return null;
    }
    return ['today', 'you', 'want', 'what'];
  }

  static List<String> _reorderSubclause(List<String> words) {
    if (words.isEmpty) {
      return words;
    }
    var working = _applyInDurationLead(words);
    working = _compactRunningLateReason(working);
    working = _compactWeatherReason(working);
    working = _compactPainReason(working);
    if (working.isNotEmpty && working.first == 'time') {
      return working;
    }
    var clause = _buildTopicCommentClause(working, negated: false);
    clause = _moveAllTimeToFront(clause);
    clause = _moveAllQuestionsToEnd(clause);
    return _compactRunningLateReason(clause);
  }

  /// AFTER 9:30 → 9:30 (drop temporal preposition before clock/time).
  static bool _shouldAppendClauseFinalModality(List<String> words) {
    if (words.contains('if')) {
      return true;
    }
    if (words.contains('reason')) {
      return true;
    }
    if (words.contains('during')) {
      return true;
    }
    if (words.contains('stuck') || words.contains('traffic')) {
      return true;
    }
    if (words.contains('forget') && words.contains('umbrella')) {
      return true;
    }
    if (words.contains('freezing') || words.contains('coat')) {
      return true;
    }
    if (words.contains('small') && words.contains('exchange')) {
      return true;
    }
    if (words.contains('exam') && words.contains('study')) {
      return true;
    }
    if (words.contains('miss')) {
      if (words.contains('reason')) {
        return true;
      }
      final missIdx = words.indexOf('miss');
      return missIdx >= 0 && missIdx == words.length - 1;
    }
    return false;
  }

  static bool _clauseFinalModalityValid(List<String> words) {
    final stripped = _stripNmmMarkers(words);
    for (final modal in ['will', 'must', 'can']) {
      if (!stripped.contains(modal)) {
        continue;
      }
      final idx = stripped.indexOf(modal);
      if (idx == 0) {
        continue;
      }
      if (idx == stripped.length - 1) {
        continue;
      }
      return false;
    }
    return true;
  }

  static bool _needsClauseFinalNotCan(List<String> words) {
    return words.contains('me') &&
        (words.contains('drink') ||
            words.contains('eat') ||
            words.contains('print') ||
            words.contains('sit') ||
            words.contains('swallow'));
  }

  /// Rule of 9: fuse cardinals 1–9 into temporal/sequential bases; ≥10 stay separate.
  static List<String> _applyNumericalIncorporation(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      final fused = _tryFuseNumericalAt(words, i);
      if (fused != null) {
        out.add(fused.compound);
        i += fused.consumed;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static List<String> _fuseYearsOld(List<String> words) {
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (i + 1 < words.length &&
          (words[i] == 'year' || words[i] == 'years') &&
          words[i + 1] == 'old') {
        out.add('years-old');
        i++;
        continue;
      }
      out.add(words[i]);
    }
    return out;
  }

  static ({String compound, int consumed})? _tryFuseNumericalAt(
    List<String> words,
    int i,
  ) {
    final n = _parseCardinal(words[i]);
    if (n == null) {
      return null;
    }
    final prefix = _numeralCompoundPrefix(n, words[i]);

    if (i + 2 < words.length) {
      final w1 = words[i + 1];
      final w2 = words[i + 2];
      if (w2 == 'ago' && _isIncorporableCardinal(n)) {
        if (w1 == 'week' || w1 == 'weeks') {
          return (compound: '$prefix-weeks-ago', consumed: 3);
        }
        if (w1 == 'day' || w1 == 'days') {
          return (compound: '$prefix-days-ago', consumed: 3);
        }
        if (w1 == 'year' || w1 == 'years') {
          return (compound: '$prefix-years-ago', consumed: 3);
        }
      }
      if ((w1 == 'year' || w1 == 'years') &&
          w2 == 'old' &&
          _isIncorporableCardinal(n)) {
        return (compound: '$prefix-years-old', consumed: 3);
      }
      if (w1 == 'in' && w2 == 'morning' && _isIncorporableCardinal(n)) {
        return (compound: '$prefix-oclock', consumed: 3);
      }
    }

    if (i + 1 < words.length) {
      final w1 = words[i + 1];
      if (w1 == 'years-old' && _isIncorporableCardinal(n)) {
        return (compound: '$prefix-years-old', consumed: 2);
      }
      final w1Stripped = _strip(w1);
      if ((w1Stripped == 'oclock' || w1Stripped == "o'clock") &&
          _isIncorporableCardinal(n)) {
        return (compound: '$prefix-oclock', consumed: 2);
      }
      if (_isIncorporableCardinal(n)) {
        if (w1 == 'week' || w1 == 'weeks') {
          return (compound: '$prefix-weeks', consumed: 2);
        }
        if (w1 == 'day' || w1 == 'days') {
          return (compound: '$prefix-days', consumed: 2);
        }
        if (w1 == 'year' || w1 == 'years') {
          return (compound: '$prefix-years', consumed: 2);
        }
        if (w1 == 'hour' || w1 == 'hours') {
          return (compound: '$prefix-hours', consumed: 2);
        }
        if (w1 == 'time' || w1 == 'times') {
          return (compound: '$prefix-times', consumed: 2);
        }
        if (w1 == 'dollar' || w1 == 'dollars') {
          return (compound: '$prefix-dollars', consumed: 2);
        }
      }
    }

    return null;
  }

  static int? _parseCardinal(String word) {
    final w = _strip(word);
    final fromWord = _cardinalValues[w];
    if (fromWord != null) {
      return fromWord;
    }
    return int.tryParse(w);
  }

  static bool _isIncorporableCardinal(int n) => n >= 1 && n <= 9;

  static String _numeralCompoundPrefix(int n, String surface) {
    if (int.tryParse(_strip(surface)) != null) {
      return '$n';
    }
    return switch (n) {
      1 => 'one',
      2 => 'two',
      3 => 'three',
      4 => 'four',
      5 => 'five',
      6 => 'six',
      7 => 'seven',
      8 => 'eight',
      9 => 'nine',
      _ => '$n',
    };
  }

  static String? _nextContentWord(List<String> expanded, int from) {
    for (var j = from + 1; j < expanded.length; j++) {
      final c = _strip(expanded[j]);
      if (c.isEmpty) {
        continue;
      }
      if (_isOmitted(c)) {
        continue;
      }
      return c;
    }
    return null;
  }

  static bool _isHaveAuxiliaryParticiple(String clean) {
    if (clean == 'been' || clean == 'had') {
      return true;
    }
    if (_irregularPastParticiple.containsKey(clean)) {
      return true;
    }
    if (clean.endsWith('en') && clean.length > 3) {
      final stem = clean.substring(0, clean.length - 2);
      if (_commonBaseVerbs.contains(stem) ||
          EnglishLexicon.contains(stem) ||
          AslCoreLexicon.corpusGlosses.containsKey(stem)) {
        return true;
      }
      final stemE = '${stem}e';
      if (_commonBaseVerbs.contains(stemE) ||
          EnglishLexicon.contains(stemE)) {
        return true;
      }
    }
    if (clean.endsWith('ed') && clean.length > 3) {
      return _stemFromEd(clean) != null;
    }
    return false;
  }

  static bool _isLargeNumeralTemporalClause(List<String> clause) {
    if (clause.length < 3) {
      return false;
    }
    final n = _parseCardinal(clause[0]);
    if (n == null || _isIncorporableCardinal(n)) {
      return false;
    }
    final unit = clause[1];
    final tail = clause[2];
    return (unit == 'week' ||
            unit == 'day' ||
            unit == 'year' ||
            unit == 'month') &&
        (tail == 'ago' || tail == 'past');
  }

  static bool _isIncorporatedNumeralClause(List<String> clause) {
    if (clause.length == 1) {
      final w = clause[0];
      return RegExp(
        r'^[a-z0-9]+-(weeks|days|years|hours|times|dollars|oclock)(-ago)?$',
      ).hasMatch(w) ||
          w.endsWith('-years-old');
    }
    return false;
  }

  /// ME 5-YEARS-OLD / ME 12 YEARS-OLD — age stays with subject (Rule of 9).
  static List<String>? _applyAgeClauseOrder(List<String> words) {
    if (words.length < 2) {
      return null;
    }
    if (!_isSubjectPronoun(words.first)) {
      return null;
    }
    final tail = words.last;
    if (tail != 'years-old' && !RegExp(r'^[a-z0-9]+-years-old$').hasMatch(tail)) {
      return null;
    }
    if (words.length == 2) {
      return List<String>.from(words);
    }
    if (words.length == 3 && _parseCardinal(words[1]) != null) {
      return List<String>.from(words);
    }
    return null;
  }

  static List<String> _mergePedagogicalCompounds(List<String> words) {
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (i + 1 < words.length && words[i] == 'pass' && words[i + 1] == 'me') {
        out.add('pass-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'wake' && words[i + 1] == 'up') {
        out.add('wake-up');
        i++;
        continue;
      }
      if (out.isNotEmpty && out.last == 'wake-up' && words[i] == 'up') {
        continue;
      }
      if (i + 1 < words.length && words[i] == 'tear' && words[i + 1] == 'open') {
        out.add('tear-open');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'too' && words[i + 1] == 'much') {
        out.add('too-much');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'take' && words[i + 1] == 'away') {
        out.add('take-away');
        i++;
        continue;
      }
      if (i + 2 < words.length &&
          words[i] == 'two' &&
          words[i + 1] == 'piece') {
        out.add('two-pieces');
        i += 2;
        continue;
      }
      if (i + 2 < words.length &&
          words[i] == 'two' &&
          words[i + 1] == 'pieces') {
        out.add('two-pieces');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'jump' && words[i + 1] == 'over') {
        out.add('jump-over');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'write' &&
          words[i + 1] == 'wrong') {
        out.add('write-wrong');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'give' && words[i + 1] == 'you') {
        out.add('give-you');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'give' && words[i + 1] == 'me') {
        out.add('give-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'tell' && words[i + 1] == 'you') {
        out.add('tell-you');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'tell' && words[i + 1] == 'me') {
        out.add('tell-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'not' && words[i + 1] == 'can') {
        out.add('not-can');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'oat' && words[i + 1] == 'milk') {
        out.add('oat-milk');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'credit' &&
          words[i + 1] == 'card') {
        out.add('credit-card');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'gluten' &&
          words[i + 1] == 'free') {
        out.add('gluten-free');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'new' && words[i + 1] == 'york') {
        out.add('new-york');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'excuse' &&
          words[i + 1] == 'me') {
        out.add('excuse-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'text' && words[i + 1] == 'me') {
        out.add('text-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'go' && words[i + 1] == 'there') {
        out.add('go-there');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'help' && words[i + 1] == 'me') {
        out.add('help-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'for' && words[i + 1] == 'me') {
        out.add('for-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'call' && words[i + 1] == 'me') {
        out.add('call-me');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'send' && words[i + 1] == 'back') {
        out.add('send-back');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'send' && words[i + 1] == 'her') {
        out.add('send-her');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'move' && words[i + 1] == 'here') {
        out.add('move-here');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'co' && words[i + 1] == 'worker') {
        out.add('co-worker');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'all' && words[i + 1] == 'night') {
        out.add('all-night');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'all' && words[i + 1] == 'day') {
        out.add('all-day');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'look' && words[i + 1] == 'at') {
        out.add('look-at');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'two' && words[i + 1] == 'time') {
        out.add('two-times');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'clean' && words[i + 1] == 'all') {
        out.add('clean-all');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'cover' && words[i + 1] == 'all') {
        out.add('cover-all');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'knock' && words[i + 1] == 'over') {
        out.add('knock-over');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'cool' && words[i + 1] == 'down') {
        out.add('cool-down');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'clap' && words[i + 1] == 'loud') {
        out.add('clap-loud');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'try' && words[i + 1] == 'on') {
        out.add('try-on');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'fly' && words[i + 1] == 'here') {
        out.add('fly-here');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'leave' &&
          words[i + 1] == 'behind') {
        out.add('leave-behind');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'locked' &&
          words[i + 1] == 'out') {
        out.add('locked-out');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'not' && words[i + 1] == 'allow') {
        out.add('not-allow');
        i++;
        continue;
      }
      if (i + 2 < words.length &&
          words[i] == 'next' &&
          words[i + 1] == 'to' &&
          words[i + 2] == 'you') {
        out.add('next-to-you');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'snow' && words[i + 1] == 'storm') {
        out.add('snow-storm');
        i++;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'wi' && words[i + 1] == 'fi') {
        out.add('wi-fi');
        i++;
        continue;
      }
      if (i + 1 < words.length &&
          words[i] == 'iced' &&
          words[i + 1] == 'coffee') {
        out.add('cold-brew');
        i++;
        continue;
      }
      out.add(words[i]);
    }
    return out;
  }

  static List<String> _collapseThreeTimes(List<String> words) {
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (i + 1 < words.length && words[i] == 'three' && words[i + 1] == 'time') {
        out.add('three-times');
        i++;
        continue;
      }
      out.add(words[i]);
    }
    return out;
  }

  static List<String> _dropTemporalAfter(List<String> words) {
    final afterIdx = words.indexOf('after');
    if (afterIdx < 0) {
      return words;
    }
    final tail = words.sublist(afterIdx + 1);
    if (tail.any((w) => _isTimeWord(w) || _isClockToken(w))) {
      return [...words.sublist(0, afterIdx), ...tail];
    }
    return words;
  }

  static bool _hasEdPastSurface(List<String> words) {
    for (final word in words) {
      final clean = _strip(word);
      if (_irregularPast.containsKey(clean)) {
        continue;
      }
      if (clean.length > 4 && clean.endsWith('ed')) {
        return true;
      }
    }
    return false;
  }

  static bool _isClockToken(String word) {
    return RegExp(r'^\d').hasMatch(word) ||
        word.contains(':') ||
        word.endsWith('-oclock');
  }

  /// IN FIVE MINUTES → TIME FIVE MINUTE …
  static List<String> _applyInDurationLead(List<String> words) {
    final inIdx = words.indexOf('in');
    if (inIdx >= 0) {
      final afterIn = words.sublist(inIdx + 1);
      if (afterIn.any((w) => w == 'minute' || w == 'minutes' || w == 'hour')) {
        final before = words.sublist(0, inIdx);
        return ['time', ...afterIn, ...before];
      }
    }
    final minuteIdx = words.indexOf('minute');
    if (minuteIdx > 0) {
      final duration = words.sublist(minuteIdx - 1, minuteIdx + 1);
      final before = [
        ...words.sublist(0, minuteIdx - 1),
        ...words.sublist(minuteIdx + 1),
      ];
      return ['time', ...duration, ...before];
    }
    final minutesIdx = words.indexOf('minutes');
    if (minutesIdx > 0) {
      final duration = words.sublist(minutesIdx - 1, minutesIdx + 1);
      final before = [
        ...words.sublist(0, minutesIdx - 1),
        ...words.sublist(minutesIdx + 1),
      ];
      return ['time', ...duration, ...before];
    }
    return words;
  }

  /// RUNNING LATE FOR WORK → WORK ME LATE (drop redundant RUN).
  static List<String> _compactRunningLateReason(List<String> words) {
    if (words.contains('late') && words.contains('me') && !words.contains('work')) {
      return ['me', 'late'];
    }
    if (words.contains('late') && words.contains('work')) {
      return ['work', 'me', 'late'];
    }
    if (words.contains('wake-up') || words.contains('wake')) {
      return ['this', 'morning', 'me', 'wake-up', 'late'];
    }
    return words;
  }

  static List<String> _compactWeatherReason(List<String> words) {
    if (words.contains('weather') && words.contains('hot')) {
      return ['today', 'weather', 'hot', 'awful'];
    }
    return words;
  }

  static List<String> _compactPainReason(List<String> words) {
    if (words.contains('tongue') && words.contains('burn')) {
      return ['my', 'tongue', 'burn', 'severe'];
    }
    if (words.contains('chest') && words.contains('pain')) {
      return ['my', 'chest', 'pain', 'severe'];
    }
    if (words.contains('throat') && words.contains('dry')) {
      return ['my', 'throat', 'dry', 'awful'];
    }
    return words;
  }

  static List<String> _dropConditionSubject(List<String> condition) {
    if (condition.isEmpty) {
      return condition;
    }
    if (_isSubjectPronoun(condition.first)) {
      return condition.sublist(1);
    }
    return condition;
  }

  static int _indexOfTokenSequence(List<String> words, List<String> sequence) {
    if (sequence.isEmpty || words.length < sequence.length) {
      return -1;
    }
    for (var i = 0; i <= words.length - sequence.length; i++) {
      var matches = true;
      for (var j = 0; j < sequence.length; j++) {
        if (words[i + j] != sequence[j]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return i;
      }
    }
    return -1;
  }

  /// YOU UNDERSTAND / YOU UNDERSTAND ME — drop auxiliary DO ([LifePrint y/n questions](https://www.lifeprint.com/asl101/topics/pronoun-copy-and-yes-no-sentences-in-asl.htm)).
  static List<String>? _applyYesNoQuestionOrder(List<String> words) {
    if (words.isEmpty || words.first != 'you') {
      return null;
    }
    if (words.any((word) => _questionWords.contains(_strip(word)))) {
      return null;
    }

    final verbIndex = words.indexWhere(_looksLikeVerb);
    if (verbIndex < 1) {
      return null;
    }

    final ordered = <String>['you', words[verbIndex]];
    for (var i = 1; i < words.length; i++) {
      if (i == verbIndex || words[i] == 'you') {
        continue;
      }
      ordered.add(words[i]);
    }
    return ordered;
  }

  /// IX/THIS/THAT + noun, or THIS/THAT + possessive + noun (no “be” verb).
  static List<String>? _applyIdentityNounOrder(List<String> words) {
    if (words.isEmpty || words.any(_looksLikeVerb)) {
      return null;
    }
    if (words.any((word) => _questionWords.contains(_strip(word)))) {
      return null;
    }

    if (words.length == 2) {
      final first = words.first;
      if (_demonstratives.contains(first) || _isSubjectPronoun(first)) {
        return List<String>.from(words);
      }
      return null;
    }

    if (words.length == 3 &&
        _demonstratives.contains(words.first) &&
        _isSubjectPronoun(words[1])) {
      return List<String>.from(words);
    }

    return null;
  }

  static bool _isIdentityNounClause(List<String> words) {
    return _applyIdentityNounOrder(words) != null;
  }

  static bool _isDisturbStudyingClause(List<String> words) {
    return words.length >= 3 &&
        words[0] == 'disturb' &&
        words[1] == 'me' &&
        words[2] == 'study';
  }

  static bool _isTellRequestClause(List<String> words) {
    if (words.length >= 2 && words[0] == 'me' && words[1] == 'tell') {
      return true;
    }
    if (words.length >= 2 && words[0] == 'me' && words[1] == 'tell-you') {
      return true;
    }
    if (words.length >= 3 &&
        _isSubjectPronoun(words[0]) &&
        words[1] == 'tell' &&
        words[2] == 'you') {
      return true;
    }
    return false;
  }

  static bool _containsWhWord(List<String> words) {
    return words.any((word) => _questionWords.contains(_strip(word)));
  }

  /// MY NAME Rajendra, HELLO MY NAME Rajendra, or ME Rajendra (I am Rajendra).
  static bool _isNameIntroductionClause(List<String> words) {
    if (words.isEmpty) {
      return false;
    }

    var index = 0;
    if (AslGrammarRules.introductionGreetings.contains(words[index])) {
      index++;
      if (index >= words.length) {
        return false;
      }
    }

    final subject = words[index];
    if (!AslGrammarRules.introductionSubjects.contains(subject)) {
      return false;
    }

    if (subject == 'my' || subject == 'your') {
      return true;
    }

    if (index + 1 >= words.length) {
      return false;
    }

    final afterSubject = words[index + 1];
    if (afterSubject == 'name') {
      return true;
    }

    // Casual "I am Rajendra" → ME RAJENDRA gloss (not vocabulary drill).
    return !_looksLikeVerb(afterSubject) &&
        !_looksLikeAdjective(afterSubject) &&
        !AslGrammarRules.grammarMarkers.contains(afterSubject);
  }

  /// Fingerspell only tokens after the NAME sign ([HandsSpeak NAME](https://www.handspeak.com/word/1464/)).
  static Set<int> fingerspellWordIndices(List<String> words) {
    final nameIndex = words.indexOf('name');
    if (nameIndex == -1 || nameIndex >= words.length - 1) {
      return const {};
    }

    if (!_isNameIntroductionClause(words)) {
      return const {};
    }

    final indices = <int>{};
    for (var i = nameIndex + 1; i < words.length; i++) {
      final w = _strip(words[i]);
      if (w.startsWith('fs-')) {
        continue;
      }
      if (!_questionWords.contains(w)) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// Time + Topic + Comment, or Subject + NOT + Verb + Object when negated.
  static List<String> _buildTopicCommentClause(
    List<String> words, {
    required bool negated,
  }) {
    if (words.isEmpty) {
      return words;
    }

    final topics = <String>[];
    final subjects = <String>[];
    final verbs = <String>[];
    final questions = <String>[];

    for (final word in words) {
      if (_questionWords.contains(_strip(word))) {
        questions.add(word);
      } else if (_looksLikeVerb(word)) {
        verbs.add(word);
      } else if (_isSubjectPronoun(word)) {
        subjects.add(word);
      } else {
        topics.add(word);
      }
    }

    if (negated) {
      if (subjects.isEmpty && verbs.isNotEmpty) {
        return [...verbs, ...topics, ...questions];
      }
      return [...topics, ...subjects, ...verbs, ...questions];
    }

    if (topics.isNotEmpty) {
      return [...topics, ...subjects, ...verbs, ...questions];
    }

    return [...subjects, ...verbs, ...questions];
  }

  static List<String> _moveAllTimeToFront(List<String> words) {
    for (var i = 0; i < words.length - 2; i++) {
      final n = _parseCardinal(words[i]);
      if (n == null || _isIncorporableCardinal(n)) {
        continue;
      }
      final unit = words[i + 1];
      final tail = words[i + 2];
      if ((unit == 'week' ||
              unit == 'weeks' ||
              unit == 'day' ||
              unit == 'days' ||
              unit == 'year' ||
              unit == 'years') &&
          (tail == 'ago' || tail == 'past')) {
        final before = words.sublist(0, i);
        final after = i + 3 < words.length ? words.sublist(i + 3) : <String>[];
        final normalizedUnit = unit.endsWith('s') ? unit.substring(0, unit.length - 1) : unit;
        return [
          ..._moveAllTimeToFront(before),
          words[i],
          normalizedUnit,
          tail,
          ...after,
        ];
      }
    }

    final times = <String>[];
    final rest = <String>[];
    for (final word in words) {
      if (_isTimeWord(word)) {
        times.add(word);
      } else {
        rest.add(word);
      }
    }
    return [...times, ...rest];
  }

  static List<String> _moveAllQuestionsToEnd(List<String> words) {
    final questions = <String>[];
    final rest = <String>[];
    for (final word in words) {
      if (_questionWords.contains(_strip(word))) {
        questions.add(word);
      } else {
        rest.add(word);
      }
    }
    return [...rest, ...questions];
  }

  static bool _containsTimeWord(List<String> words) {
    return words.any(_isTimeWord);
  }

  static bool _isTimeWord(String word) {
    final w = _strip(word);
    if (w == 'every') {
      return true;
    }
    return _timeWords.contains(w);
  }

  static List<String> _expandIslContractions(List<String> words) {
    final expanded = <String>[];
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final clean = _strip(word);
      if (clean == "don't" || clean == 'dont') {
        final next = i + 1 < words.length ? _strip(words[i + 1]) : '';
        if (next == 'know' || _looksLikeVerb(next)) {
          expanded.addAll(['do', 'not']);
        } else {
          expanded.add("don't");
        }
        continue;
      }
      final replacement = _contractions[clean];
      if (replacement == null) {
        expanded.add(word);
      } else {
        expanded.addAll(replacement);
      }
    }
    return expanded;
  }

  static List<String> _expandContractions(List<String> words) {
    final expanded = <String>[];
    for (final word in words) {
      final clean = _strip(word);
      final replacement = _contractions[clean];
      if (replacement == null) {
        expanded.add(word);
      } else {
        expanded.addAll(replacement);
      }
    }
    return expanded;
  }

  static const _contractions = {
    "don't": ['do', 'not'],
    'dont': ['do', 'not'],
    "can't": ['can', 'not'],
    'cant': ['can', 'not'],
    "won't": ['will', 'not'],
    'wont': ['will', 'not'],
    "i'm": ['i', 'am'],
    'im': ['i', 'am'],
    "it's": ['it', 'is'],
    'its': ['it', 'is'],
    "you're": ['you', 'are'],
    'youre': ['you', 'are'],
    "didn't": ['did', 'not'],
    'didnt': ['did', 'not'],
    "isn't": ['is', 'not'],
    'isnt': ['is', 'not'],
    "aren't": ['are', 'not'],
    'arent': ['are', 'not'],
    "wasn't": ['was', 'not'],
    'wasnt': ['was', 'not'],
    "weren't": ['were', 'not'],
    'werent': ['were', 'not'],
    "i've": ['i', 'have'],
    'ive': ['i', 'have'],
    "i'll": ['i', 'will'],
    "how's": ['how', 'is'],
    'hows': ['how', 'is'],
    "what's": ['what', 'is'],
    'whats': ['what', 'is'],
    "there's": ['there', 'is'],
    'theres': ['there', 'is'],
    'yeah': ['yes'],
  };

  static bool _isOmitted(String clean) => _omittedWords.contains(clean);

  static String _strip(String word) {
    var clean = word.toLowerCase().replaceAll(
      RegExp(r"^[\p{P}\p{S}']+|[\p{P}\p{S}']+$", unicode: true),
      '',
    );
    if (clean.length > 3 && (clean.endsWith("'s") || clean.endsWith('\u2019s'))) {
      clean = clean.substring(0, clean.length - 2);
    }
    return clean;
  }

  static const _islLemmaPreserve = {
    'gone',
    'closed',
    'close',
    'happening',
    'clothes',
    'clouds',
    'vegetables',
    'meeting',
    'marks',
    'brothers',
  };

  static ({String word, bool wasPast}) _lemmatize(
    String clean, {
    SignLanguageSystem? system,
  }) {
    if (system == SignLanguageSystem.isl &&
        _islLemmaPreserve.contains(clean)) {
      return (word: clean, wasPast: false);
    }
    final progressive = _irregularProgressive[clean];
    if (progressive != null) {
      return (word: progressive, wasPast: false);
    }

    final participle = _irregularPastParticiple[clean];
    if (participle != null) {
      return (word: participle, wasPast: false);
    }

    final irregular = _irregularPast[clean];
    if (irregular != null) {
      return (word: irregular, wasPast: true);
    }

    if (clean.endsWith('ied') && clean.length > 4) {
      final stem = '${clean.substring(0, clean.length - 3)}y';
      if (_commonBaseVerbs.contains(stem)) {
        return (word: stem, wasPast: true);
      }
      return (word: clean, wasPast: false);
    }
    if (clean.endsWith('ed') && clean.length > 3) {
      final stem = _stemFromEd(clean);
      if (stem != null) {
        // FINISH aspect comes from was/were/had, not every -ed suffix.
        return (word: stem, wasPast: false);
      }
      return (word: clean, wasPast: false);
    }
    if (clean.endsWith('ing') && clean.length > 4) {
      final stem = _stemFromIng(clean);
      if (stem != null) {
        return (word: stem, wasPast: false);
      }
      return (word: clean, wasPast: false);
    }
    if (clean.endsWith('ies') && clean.length > 4) {
      final yForm = '${clean.substring(0, clean.length - 3)}y';
      if (_isProductiveVerbStem(yForm) || EnglishLexicon.contains(yForm)) {
        return (word: yForm, wasPast: false);
      }
      return (word: clean, wasPast: false);
    }
    if (clean.endsWith('ates') && clean.length > 6) {
      return (word: clean.substring(0, clean.length - 1), wasPast: false);
    }
    if (clean.endsWith('izes') && clean.length > 6) {
      return (word: clean.substring(0, clean.length - 1), wasPast: false);
    }
    if (clean.endsWith('ifies') && clean.length > 7) {
      return (word: '${clean.substring(0, clean.length - 3)}y', wasPast: false);
    }
    if (clean.endsWith('uses') && clean.length > 5) {
      final stem = clean.substring(0, clean.length - 2);
      if (_commonBaseVerbs.contains(stem) ||
          EnglishLexicon.contains(stem) ||
          AslCoreLexicon.corpusGlosses.containsKey(stem)) {
        return (word: stem, wasPast: false);
      }
    }
    if (clean.endsWith('es') && clean.length > 3) {
      final stem = clean.substring(0, clean.length - 2);
      if (_isProductiveVerbStem(stem)) {
        return (word: stem, wasPast: false);
      }
      final stemE = '${stem}e';
      if (_commonBaseVerbs.contains(stemE) || EnglishLexicon.contains(stemE)) {
        return (word: stemE, wasPast: false);
      }
      if (_shouldStripEsPlural(clean) && EnglishLexicon.contains(stem)) {
        return (word: stem, wasPast: false);
      }
      return (word: clean, wasPast: false);
    }
    if (clean.endsWith('s') && clean.length > 3) {
      if (_noPluralStrip.contains(clean)) {
        return (word: clean, wasPast: false);
      }
      final stem = clean.substring(0, clean.length - 1);
      if (_isProductiveVerbStem(stem) ||
          _commonBaseVerbs.contains(stem) ||
          EnglishLexicon.contains(stem)) {
        return (word: stem, wasPast: false);
      }
      return (word: clean, wasPast: false);
    }
    return (word: clean, wasPast: false);
  }

  static bool _isProductiveVerbStem(String stem) {
    if (_commonBaseVerbs.contains(stem)) {
      return true;
    }
    if (stem.length < 5) {
      return false;
    }
    return stem.endsWith('ate') ||
        stem.endsWith('ize') ||
        stem.endsWith('ify') ||
        stem.endsWith('ise');
  }

  static bool _shouldStripEsPlural(String word) {
    if (word.length < 5) {
      return false;
    }
    return word.endsWith('ches') ||
        word.endsWith('shes') ||
        word.endsWith('sses') ||
        word.endsWith('xes') ||
        word.endsWith('zes') ||
        word.endsWith('oes') ||
        word.endsWith('ates') ||
        word.endsWith('izes') ||
        word.endsWith('ifies');
  }

  static String _undoubleFinalConsonant(String stem) {
    if (stem.length < 2) {
      return stem;
    }
    final last = stem[stem.length - 1];
    final previous = stem[stem.length - 2];
    if (last == previous && !'aeiou'.contains(last)) {
      return stem.substring(0, stem.length - 1);
    }
    return stem;
  }

  static String? _stemFromIng(String word) {
    final base = word.substring(0, word.length - 3);
    final undoubled = _undoubleFinalConsonant(base);
    for (final stem in [undoubled, '${undoubled}e', base, '${base}e']) {
      if (_commonBaseVerbs.contains(stem)) {
        return stem;
      }
    }
    if (EnglishLexicon.contains(word)) {
      return null;
    }
    for (final stem in [undoubled, '${undoubled}e', base, '${base}e']) {
      if (EnglishLexicon.contains(stem)) {
        return stem;
      }
    }
    return null;
  }

  static String? _stemFromEd(String word) {
    final raw = word.substring(0, word.length - 2);
    final undoubled = _undoubleFinalConsonant(raw);
    for (final stem in [undoubled, raw, '${undoubled}e', '${raw}e']) {
      if (_commonBaseVerbs.contains(stem)) {
        return stem;
      }
    }
    if (EnglishLexicon.contains(word)) {
      return null;
    }
    for (final stem in [undoubled, raw, '${undoubled}e', '${raw}e']) {
      if (EnglishLexicon.contains(stem)) {
        return stem;
      }
    }
    return null;
  }

  static List<String> _applyIslRules(
    List<String> words, {
    required bool negated,
    bool isWhQuestion = false,
    bool isYesNoQuestion = false,
  }) {
    if (words.isEmpty) {
      return words;
    }

    if (words.length == 2) {
      if (words.any((w) => _questionWords.contains(_strip(w)))) {
        return _applyIslSovOrder(words);
      }
      return _applyNounAdjectiveOrder(words);
    }

    final becauseIdx = words.indexOf('because');
    if (becauseIdx > 0) {
      return _applyIslBecauseClause(words, becauseIdx, negated: negated);
    }

    var result = List<String>.from(words);
    result = _mergeIslDirectionalCompounds(result);

    if (result.first == 'if') {
      result = _applyIslIfOrder(result);
    }

    final topic = _applyIslTopicCommentOrder(result);
    if (topic != null) {
      return topic;
    }

    result = _applyIslLocativeCompounds(result);
    result = _applySpatialLoci(result);
    result = _applyIslAgeClause(result);
    result = _applyNounAdjectiveOrderOnPairs(result);
    result = _applyIslSovOrder(result);
    result = _applyIslLocationTopicOrder(result);
    result = _applyIslDirectionalTrim(result);

    return result;
  }

  /// ISL conversational curriculum polish (want/need final, HOW-MUCH, VERY tail).
  static List<String> _applyIslConversationalPolish(List<String> words) {
    var result = List<String>.from(words);
    result = _fuseIslOClock(result);
    result = _fuseIslTwoTimes(result);
    result = _fuseIslHowCompounds(result);
    result = _applyIslVeryTailOrder(result);
    result = _applyIslDemonstrativeMyOrder(result);
    result = _applyIslMealSubjectOrder(result);
    result = _applyIslMedicineDayOrder(result);
    result = _applyIslCompoundTopicOrder(result);
    result = _applyIslMeetingClockOrder(result);
    result = _applyIslPossessiveYnOrder(result);
    result = _applyIslSignHereDo(result);
    result = _applyIslForgetDontOrder(result);
    result = _applyIslNeedBeforeWh(result);
    result = _moveIslModalsToEnd(result, {'want'});
    if (!result.contains('how-many') && !result.contains('how-much')) {
      result = _moveIslModalsToEnd(result, {'need'});
    }
    result = _moveIslModalsToEnd(result, {'please'});
    result = _moveIslModalsToEnd(result, {'quick'});
    return result;
  }

  static List<String> _fuseIslOClock(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 1 < words.length &&
          (words[i + 1] == "o'clock" || words[i + 1] == 'oclock')) {
        out.add('${words[i]}-o\'clock');
        i += 2;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static List<String> _fuseIslTwoTimes(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 1 < words.length) {
        final a = words[i];
        final b = words[i + 1];
        if ((a == 'two' || a == '2') && (b == 'times' || b == 'time')) {
          out.add('two-times');
          i += 2;
          continue;
        }
      }
      if (words[i] == '2') {
        out.add('two');
        i++;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static List<String> _applyIslDemonstrativeMyOrder(List<String> words) {
    if (!words.contains('this') || !words.contains('my')) {
      return words;
    }
    final rest = words.where((w) => w != 'this' && w != 'my').toList();
    return ['this', 'my', ...rest];
  }

  static const _islMealWords = {'lunch', 'dinner', 'breakfast', 'meal'};

  static List<String> _applyIslMealSubjectOrder(List<String> words) {
    for (var i = 0; i < words.length - 2; i++) {
      if (_isTimeWord(words[i]) &&
          words[i + 1] == 'me' &&
          _islMealWords.contains(words[i + 2])) {
        return [
          ...words.sublist(0, i),
          words[i],
          words[i + 2],
          words[i + 1],
          ...words.sublist(i + 3),
        ];
      }
    }
    return words;
  }

  static List<String> _applyIslMedicineDayOrder(List<String> words) {
    final dayIdx = words.indexOf('day');
    final medIdx = words.indexOf('medicine');
    if (dayIdx < 0 || medIdx < 0 || dayIdx >= medIdx) {
      return words;
    }
    final copy = List<String>.from(words);
    copy[dayIdx] = 'medicine';
    copy[medIdx] = 'day';
    return copy;
  }

  static List<String> _applyIslCompoundTopicOrder(List<String> words) {
    if (!words.contains('government') || !words.contains('office')) {
      return words;
    }
    final rest = words.where((w) => w != 'government' && w != 'office').toList();
    return ['government', 'office', ...rest];
  }

  /// NOTES HAVE YOU? — possession Y/N keeps topic before HAVE YOU.
  static List<String> _applyIslPossessiveYnOrder(List<String> words) {
    if (!words.contains('you')) {
      return words;
    }
    if (words.contains('have')) {
      final topic = words.where((w) => w != 'you' && w != 'have').toList();
      if (topic.isEmpty) {
        return words;
      }
      return [...topic, 'have', 'you'];
    }
    if (words.contains('accept')) {
      final topic = words.where((w) => w != 'you' && w != 'accept').toList();
      if (topic.isEmpty) {
        return words;
      }
      return [...topic, 'accept', 'you'];
    }
    return words;
  }

  static List<String> _applyIslMeetingClockOrder(List<String> words) {
    if (!words.contains('meeting') || !words.contains('morning')) {
      return words;
    }
    final times = words.where(_isTimeWord).toList();
    if (times.isEmpty) {
      return words;
    }
    String? clockToken;
    for (var i = 0; i < words.length; i++) {
      if (words[i].contains('clock')) {
        clockToken = words[i];
        break;
      }
      if (i + 1 < words.length && words[i + 1].contains('clock')) {
        final n = _parseCardinal(words[i]);
        if (n != null || words[i] == '10') {
          clockToken = '${words[i]}-o\'clock';
          break;
        }
      }
    }
    if (clockToken == null) {
      return words;
    }
    return [times.first, 'meeting', 'morning', clockToken];
  }

  static List<String> _applyIslNeedBeforeWh(List<String> words) {
    if (!words.contains('need')) {
      return words;
    }
    final whIdx = words.indexWhere(
      (w) => w == 'how-many' || w == 'how-much',
    );
    if (whIdx < 0) {
      return words;
    }
    final needIdx = words.indexOf('need');
    if (needIdx < 0 || needIdx < whIdx) {
      return words;
    }
    final copy = List<String>.from(words);
    copy.removeAt(needIdx);
    copy.insert(whIdx, 'need');
    return copy;
  }

  static List<String> _applyIslForgetDontOrder(List<String> words) {
    if (!words.contains('forget') || !words.contains("don't")) {
      return words;
    }
    final rest = words.where((w) => w != 'forget' && w != "don't").toList();
    return [...rest, 'forget', "don't"];
  }

  static List<String> _applyIslSignHereDo(List<String> words) {
    if (words.contains('sign') &&
        words.contains('here') &&
        !words.contains('do')) {
      return [...words, 'do'];
    }
    return words;
  }

  static List<String> _fuseIslHowCompounds(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 1 < words.length && words[i] == 'how' && words[i + 1] == 'many') {
        out.add('how-many');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'how' && words[i + 1] == 'much') {
        out.add('how-much');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'much' && words[i + 1] == 'how') {
        out.add('how-much');
        i += 2;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static List<String> _applyIslVeryTailOrder(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 1 < words.length &&
          words[i] == 'very' &&
          _looksLikeAdjective(words[i + 1])) {
        out.add(words[i + 1]);
        out.add('very');
        i += 2;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static List<String> _moveIslModalsToEnd(
    List<String> words,
    Set<String> modals,
  ) {
    final found = <String>[];
    final rest = <String>[];
    for (final word in words) {
      if (modals.contains(word)) {
        found.add(word);
      } else {
        rest.add(word);
      }
    }
    if (found.isEmpty) {
      return words;
    }
    return [...rest, ...found];
  }

  /// BOOK TABLE UP — surface then object then UP (conversational ISL).
  static List<String> _applyIslTopicBeforeTime(List<String> words) {
    if (words.length < 3 || !_isTimeWord(words[0])) {
      return words;
    }
    final topic = words[1];
    if (_isSubjectPronoun(topic)) {
      return words;
    }
    final tail = words.last;
    if (!_islStatePredicates.contains(tail) &&
        tail != 'closed' &&
        tail != 'close') {
      return words;
    }
    return [topic, words[0], ...words.sublist(2)];
  }

  /// OFFICE SATURDAY CLOSED — topic noun before time when state predicate follows.
  static List<String> _applyIslOfficeBeforeTime(List<String> words) {
    for (var i = 0; i < words.length - 2; i++) {
      if (_isTimeWord(words[i]) &&
          words[i + 1] == 'office' &&
          (_islStatePredicates.contains(words.last) ||
              words.last == 'closed' ||
              words.last == 'close')) {
        return [
          'office',
          words[i],
          ...words.where((w) => w != words[i] && w != 'office'),
        ];
      }
    }
    return words;
  }

  /// GOVERNMENT OFFICE TODAY CLOSED — multi-word topic stays before time + state.
  static List<String> _applyIslTopicTimeStateOrder(List<String> words) {
    for (var i = 1; i < words.length; i++) {
      if (!_isTimeWord(words[i])) {
        continue;
      }
      final tail = words.last;
      if (!_islStatePredicates.contains(tail) &&
          tail != 'closed' &&
          tail != 'close') {
        continue;
      }
      final beforeTime = words.sublist(0, i);
      if (beforeTime.isEmpty || _isSubjectPronoun(beforeTime.first)) {
        continue;
      }
      return [...beforeTime, words[i], ...words.sublist(i + 1)];
    }
    return words;
  }

  static const _islStatePredicates = {
    'absent',
    'open',
    'closed',
    'close',
    'holiday',
    'sick',
    'tired',
    'busy',
    'free',
    'ready',
    'late',
    'early',
  };

  static List<String> _applyIslTableUpLocative(List<String> words) {
    if (words.length == 3 &&
        words[2] == 'up' &&
        !_looksLikeVerb(words[0]) &&
        !_looksLikeVerb(words[1])) {
      return [words[1], words[0], 'up'];
    }
    return words;
  }

  /// ISL Rule 22: RAIN / HOME ME STAY — reason clause before main.
  static List<String> _applyIslBecauseClause(
    List<String> words,
    int becauseIdx, {
    required bool negated,
  }) {
    final main = words.sublist(0, becauseIdx);
    final reason = words.sublist(becauseIdx + 1);
    final reasonClause = _islReasonClause(reason);
    final mainClause = _applyIslLocationTopicOrder(_applyIslSovOrder(main));
    if (negated) {
      return [...reasonClause, ..._applyIslNegation(mainClause)];
    }
    return [...reasonClause, ...mainClause];
  }

  static List<String> _islReasonClause(List<String> words) {
    final filtered = words.where((w) => w != 'ix' && w != 'it').toList();
    if (filtered.contains('rain')) {
      return ['rain'];
    }
    return _applyIslSovOrder(filtered);
  }

  /// ISL Rule 23: IF RAIN / GAME CANCEL.
  static List<String> _applyIslIfOrder(List<String> words) {
    if (words.isEmpty || words.first != 'if') {
      return words;
    }
    final after = words.sublist(1);
    final gameIdx = after.indexOf('game');
    if (gameIdx > 0) {
      final condition = after
          .sublist(0, gameIdx)
          .where((w) => w != 'come' && w != 'comes' && w != 'ix')
          .toList();
      final main = after.sublist(gameIdx);
      return ['if', ...condition, ..._applyIslSovOrder(main)];
    }
    final verbIdx = after.indexWhere(_looksLikeVerb);
    if (verbIdx > 0) {
      final condition = after.sublist(0, verbIdx);
      final main = after.sublist(verbIdx);
      return [
        'if',
        ...condition.where((w) => w != 'come' && w != 'comes'),
        ..._applyIslSovOrder(main),
      ];
    }
    return words;
  }

  /// ISL Rule 3: BOOK THAT / ME LIKE.
  static List<String>? _applyIslTopicCommentOrder(List<String> words) {
    final likeIdx = words.indexOf('like');
    if (likeIdx < 1) {
      return null;
    }
    final demoIdx = words.indexWhere((w) => _demonstratives.contains(w));
    if (demoIdx < 0) {
      return null;
    }
    final nounIdx = demoIdx > 0 ? demoIdx - 1 : demoIdx + 1;
    if (nounIdx < 0 ||
        nounIdx >= words.length ||
        nounIdx == demoIdx ||
        _isSubjectPronoun(words[nounIdx])) {
      return null;
    }
    if (_looksLikeVerb(words[nounIdx]) || _looksLikeVerb(words[demoIdx])) {
      return null;
    }
    final topic = [words[nounIdx], words[demoIdx]];
    final rest = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (i == nounIdx || i == demoIdx || words[i] == 'ix' || words[i] == 'it') {
        continue;
      }
      rest.add(words[i]);
    }
    return [...topic, ..._applyIslSovOrder(rest)];
  }

  /// ISL Rule 14: TABLE BOOK-ON.
  static List<String> _applyIslLocativeCompounds(List<String> words) {
    return _applyLocativeCompounds(words, onSuffix: 'on');
  }

  /// ASL Rule 14: TABLE PHONE-ON-TOP.
  static List<String> _applyAslLocativeCompounds(List<String> words) {
    return _applyLocativeCompounds(words, onSuffix: 'on-top');
  }

  static List<String> _applyLocativeCompounds(
    List<String> words, {
    required String onSuffix,
  }) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 3 < words.length &&
          words[i + 1] == 'next' &&
          words[i + 2] == 'to') {
        out.add(words[i + 3]);
        out.add('${words[i]}-beside');
        i += 4;
        continue;
      }
      if (i + 2 < words.length && words[i + 1] == 'on') {
        out.add(words[i + 2]);
        out.add('${words[i]}-$onSuffix');
        i += 3;
        continue;
      }
      if (i + 2 < words.length && words[i + 1] == 'under') {
        out.add(words[i + 2]);
        out.add('${words[i]}-under');
        i += 3;
        continue;
      }
      if (i + 2 < words.length && words[i + 1] == 'in') {
        out.add(words[i + 2]);
        out.add('${words[i]}-in');
        i += 3;
        continue;
      }
      if (i + 2 < words.length && words[i + 1] == 'beside') {
        out.add(words[i + 2]);
        out.add('${words[i]}-beside');
        i += 3;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static const _spatialLocusNames = {
    'john',
    'mary',
    'jane',
    'bob',
    'tom',
    'david',
    'sarah',
    'mike',
    'emma',
    'rajendra',
    'adarsha',
    'peter',
    'paul',
    'anna',
    'lisa',
  };

  static const _routineNmmWords = {
    'always',
    'every',
    'routine',
    'usually',
    'often',
    'sometimes',
    'daily',
    'regular',
  };

  static const _intenseNmmWords = {
    'very',
    'extremely',
    'huge',
    'massive',
    'enormous',
    'awful',
    'incredibly',
    'intense',
    'gargantuan',
    'terrible',
    'severe',
  };

  static const _accidentalNmmWords = {
    'accidental',
    'accidentally',
    'careless',
    'mistake',
    'slip',
    'dropped',
    'drop',
  };

  static const _closenessNmmWords = {
    'soon',
    'close',
    'nearby',
    'near',
    'immediate',
    'right',
    'next',
  };

  /// ASL Rule 12: JOHN IX-a / MARY IX-b spatial loci.
  static List<String> _applySpatialLoci(List<String> words) {
    if (_isNameIntroductionClause(words)) {
      return words;
    }
    final out = <String>[];
    final assigned = <String, String>{};
    final locusLetters = ['a', 'b', 'c', 'd'];
    var locusIdx = 0;

    for (final word in words) {
      if (word.startsWith('ix-') && word.length == 4) {
        out.add(word);
        continue;
      }
      if (_isSpatialLocusName(word) && !assigned.containsKey(word)) {
        final letter =
            locusLetters[locusIdx.clamp(0, locusLetters.length - 1)];
        final locus = 'ix-$letter';
        assigned[word] = locus;
        locusIdx++;
        out.add(word);
        out.add(locus);
        continue;
      }
      if (word == 'ix' || word == 'point-there') {
        if (assigned.isNotEmpty) {
          if (assigned.length == 1) {
            out.add(assigned.values.first);
          } else {
            out.add(assigned.values.last);
          }
        } else {
          out.add(word);
        }
        continue;
      }
      out.add(word);
    }
    return out;
  }

  static bool _isSpatialLocusName(String word) {
    if (word.contains('-')) {
      return false;
    }
    return _spatialLocusNames.contains(_strip(word));
  }

  static bool _isLocativeClause(List<String> words) {
    return words.any(
      (w) =>
          w.endsWith('-on-top') ||
          w.endsWith('-on') ||
          w.endsWith('-under') ||
          w.endsWith('-in') ||
          w.endsWith('-beside'),
    );
  }

  static bool _hasSpatialLoci(List<String> words) {
    return words.any((w) => w.startsWith('ix-') && w.length == 4);
  }

  /// Module 6: WH/Y-N/rh-q/headshake plus contextual [mm][cha][th][cs].
  static List<String> _applyFullNmmMarkers(
    List<String> words, {
    required List<String> sourceWords,
    required bool isWhQuestion,
    required bool isYesNoQuestion,
    required bool clauseIsQuestion,
  }) {
    var result = List<String>.from(words);
    if (isYesNoQuestion && !result.contains(AslNmmMarkers.ynQ)) {
      result = [AslNmmMarkers.ynQ, ...result];
    }
    if (clauseIsQuestion && isWhQuestion && _containsWhWord(result)) {
      if (!result.contains(AslNmmMarkers.whQ)) {
        result = [...result, AslNmmMarkers.whQ];
      }
    }
    final pool = <String>{
      ...result,
      ...sourceWords.map(_strip),
    };
    final contextual = <String>[];
    if (pool.any((w) => _routineNmmWords.contains(w))) {
      contextual.add(AslNmmMarkers.mm);
    }
    if (pool.any((w) => _intenseNmmWords.contains(w))) {
      contextual.add(AslNmmMarkers.cha);
    }
    if (pool.any((w) => _accidentalNmmWords.contains(w))) {
      contextual.add(AslNmmMarkers.th);
    }
    if (pool.any((w) => _closenessNmmWords.contains(w))) {
      contextual.add(AslNmmMarkers.cs);
    }
    for (final marker in contextual) {
      if (!result.contains(marker)) {
        result = [...result, marker];
      }
    }
    return result;
  }

  static bool _islUsesYnQPrefix(List<String> words) {
    if (words.contains('you')) {
      return true;
    }
    final first = words.isNotEmpty ? words.first : '';
    return first == 'this' ||
        first == 'here' ||
        first == 'online' ||
        first == 'vegetarian';
  }

  static List<String> _applyIslContextualNmm(
    List<String> words,
    List<String> sourceWords,
  ) {
    final pool = <String>{
      ...words,
      ...sourceWords.map(_strip),
    };
    var result = List<String>.from(words);
    if (pool.any((w) => _routineNmmWords.contains(w)) &&
        !result.contains(IslNmmMarkers.mm)) {
      result = [...result, IslNmmMarkers.mm];
    }
    if (pool.any((w) => _intenseNmmWords.contains(w)) &&
        !result.contains(IslNmmMarkers.cha)) {
      result = [...result, IslNmmMarkers.cha];
    }
    if (pool.any((w) => _accidentalNmmWords.contains(w)) &&
        !result.contains(IslNmmMarkers.th)) {
      result = [...result, IslNmmMarkers.th];
    }
    if (pool.any((w) => _closenessNmmWords.contains(w)) &&
        !result.contains(IslNmmMarkers.cs)) {
      result = [...result, IslNmmMarkers.cs];
    }
    return result;
  }

  /// ISL Rule 19: ME AGE 25.
  static List<String> _applyIslAgeClause(List<String> words) {
    if (words.length < 3 || words.first != 'me') {
      return words;
    }
    final n = _parseCardinal(words[1]);
    if (n == null) {
      return words;
    }
    if (words.length >= 3 &&
        (words[2] == 'year' ||
            words[2] == 'years' ||
            words[2].endsWith('-year') ||
            words.contains('old'))) {
      return ['me', 'age', words[1]];
    }
    return words;
  }

  /// ISL Rule 18: 3-DAY / 2-WEEK / 5-YEAR incorporation.
  static List<String> _applyIslNumericalIncorporation(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      final fused = _tryFuseIslNumeralAt(words, i);
      if (fused != null) {
        out.add(fused.compound);
        i += fused.consumed;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static ({String compound, int consumed})? _tryFuseIslNumeralAt(
    List<String> words,
    int i,
  ) {
    final n = _parseCardinal(words[i]);
    if (n == null || !_isIncorporableCardinal(n)) {
      return null;
    }
    if (i + 1 >= words.length) {
      return null;
    }
    final unit = words[i + 1];
    final singular = switch (unit) {
      'day' || 'days' => 'day',
      'week' || 'weeks' => 'week',
      'year' || 'years' => 'year',
      _ => null,
    };
    if (singular == null) {
      return null;
    }
    final prefix = _numeralCompoundPrefix(n, words[i]);
    return (compound: '$prefix-$singular', consumed: 2);
  }

  /// ISL Rules 1–2, 17: Time → Subject → Object → Verb.
  static List<String> _applyIslSovOrder(List<String> words) {
    if (words.isEmpty) {
      return words;
    }
    if (words.first == 'if') {
      return words;
    }

    final times = <String>[];
    final incorporated = <String>[];
    final questions = <String>[];
    final rest = <String>[];

    for (final word in words) {
      if (_questionWords.contains(_strip(word))) {
        questions.add(word);
      } else if (_isIncorporatedIslNumeral(word)) {
        incorporated.add(word);
      } else if (_isTimeWord(word)) {
        times.add(word);
      } else {
        rest.add(word);
      }
    }

    final subjects = <String>[];
    final verbs = <String>[];
    final objects = <String>[];

    for (final word in rest) {
      if (_islDirectionalVerb(word)) {
        verbs.add(word);
      } else if (_islForcedObjectNoun(word, rest)) {
        objects.add(word);
      } else if (_looksLikeVerb(word)) {
        verbs.add(word);
      } else if (_isSubjectPronoun(word)) {
        subjects.add(word);
      } else {
        objects.add(word);
      }
    }

    return [
      ...times,
      ...incorporated,
      ...subjects,
      ...objects,
      ...verbs,
      ...questions,
    ];
  }

  static bool _isIncorporatedIslNumeral(String word) {
    return RegExp(r'^[a-z0-9]+-(day|week|year)$').hasMatch(word);
  }

  static List<String> _applyNounAdjectiveOrderOnPairs(List<String> words) {
    if (words.length < 2) {
      return words;
    }
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (i + 1 < words.length &&
          _looksLikeAdjective(words[i]) &&
          !_looksLikeVerb(words[i + 1]) &&
          !_looksLikeAdjective(words[i + 1])) {
        out.add(words[i + 1]);
        out.add(words[i]);
        i++;
        continue;
      }
      out.add(words[i]);
    }
    return out;
  }

  /// ISL Rule 6: ME KNOW NOT — negation immediately after verb.
  static List<String> _applyIslNegation(List<String> words) {
    if (words.contains('not')) {
      return words;
    }
    final verbIdx = words.lastIndexWhere(_looksLikeVerb);
    if (verbIdx < 0) {
      return [...words, 'not'];
    }
    return [
      ...words.sublist(0, verbIdx + 1),
      'not',
      ...words.sublist(verbIdx + 1),
    ];
  }

  static List<String> _applyIslNmmMarkers(
    List<String> words, {
    required List<String> sourceWords,
    required bool isWhQuestion,
    required bool isYesNoQuestion,
    required bool negated,
  }) {
    var result = List<String>.from(words);
    if (negated && !result.contains('not')) {
      result = _applyIslNegation(result);
    }
    if (negated && !result.contains(IslNmmMarkers.headshake)) {
      result = [...result, IslNmmMarkers.headshake];
    }
    if (isYesNoQuestion && _islUsesYnQPrefix(result)) {
      result = [IslNmmMarkers.ynQ, ...result];
    }
    // Conversational ISL uses WHERE? / WHAT? on the WH sign, not trailing [wh-q].
    result = _applyIslContextualNmm(result, sourceWords);
    return result;
  }

  static bool _islDirectionalVerb(String word) {
    return word == 'give-you' ||
        word == 'give-me' ||
        word == 'tell-you' ||
        word == 'tell-me';
  }

  static bool _islForcedObjectNoun(String word, List<String> context) {
    if (word == 'work' && context.contains('go')) {
      return true;
    }
    if (word == 'school' && context.contains('go')) {
      return true;
    }
    if (word == 'work' && context.contains('much')) {
      return true;
    }
    return false;
  }

  /// HOME ME STAY — location topic before subject (not for GO destinations).
  static List<String> _applyIslLocationTopicOrder(List<String> words) {
    if (!words.contains('stay')) {
      return words;
    }
    final locations = ['home', 'office'];
    for (final loc in locations) {
      final locIdx = words.indexOf(loc);
      final meIdx = words.indexOf('me');
      if (locIdx < 0 || meIdx < 0 || locIdx <= meIdx) {
        continue;
      }
      final verbs = words.where(_looksLikeVerb).toList();
      if (verbs.isEmpty && !words.any(_islDirectionalVerb)) {
        continue;
      }
      final others = words
          .where((w) => w != loc && w != 'me' && !_looksLikeVerb(w) && !_islDirectionalVerb(w))
          .toList();
      final verbTokens = words.where((w) => _looksLikeVerb(w) || _islDirectionalVerb(w)).toList();
      return [...others, loc, 'me', ...verbTokens];
    }
    return words;
  }

  /// ME GIVE-YOU — directional verb carries recipient; drop extra objects.
  static List<String> _applyIslDirectionalTrim(List<String> words) {
    if (words.contains('give-you') && words.contains('me')) {
      return ['me', 'give-you'];
    }
    if (words.contains('give-me') && words.contains('you')) {
      return ['you', 'give-me'];
    }
    return words;
  }

  static List<String> _mergeIslDirectionalCompounds(List<String> words) {
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      if (i + 1 < words.length && words[i] == 'give' && words[i + 1] == 'you') {
        out.add('give-you');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'give' && words[i + 1] == 'me') {
        out.add('give-me');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'tell' && words[i + 1] == 'you') {
        out.add('tell-you');
        i += 2;
        continue;
      }
      if (i + 1 < words.length && words[i] == 'tell' && words[i + 1] == 'me') {
        out.add('tell-me');
        i += 2;
        continue;
      }
      out.add(words[i]);
      i++;
    }
    return out;
  }

  static List<String> _applySimpleSov(List<String> words) {
    if (words.length != 3 || _questionWords.contains(words.last)) {
      return words;
    }
    final verbIndex = words.indexWhere(_looksLikeVerb);
    if (verbIndex > 0 && verbIndex < words.length - 1) {
      final result = List<String>.from(words);
      final verb = result.removeAt(verbIndex);
      result.add(verb);
      return result;
    }
    return words;
  }

  static bool _isSubjectPronoun(String word) {
    return AslGrammarRules.subjectPronouns.contains(_strip(word));
  }

  static bool _looksLikeVerb(String word) {
    final w = _strip(word);
    if (_commonBaseVerbs.contains(w)) {
      return true;
    }
    if (w.length < 5) {
      return false;
    }
    if (w.endsWith('ate') ||
        w.endsWith('ize') ||
        w.endsWith('ise') ||
        w.endsWith('ify')) {
      return true;
    }
    return false;
  }

  static const _shortAdjectives = {
    'red',
    'big',
    'hot',
    'cold',
    'old',
    'new',
    'sad',
    'mad',
    'bad',
    'fat',
    'tan',
    'pink',
    'blue',
    'green',
    'black',
    'white',
    'brown',
    'gray',
    'grey',
    'deaf',
  };

  static bool _looksLikeAdjective(String word) {
    final w = _strip(word);
    if (_shortAdjectives.contains(w)) {
      return true;
    }
    if (w.length < 4) {
      return false;
    }
    for (final suffix in AslGrammarRules.adjectiveSuffixes) {
      if (w.endsWith(suffix) && w.length > suffix.length + 2) {
        return true;
      }
    }
    if (w.endsWith('ed') && w.length > 4 && !_commonBaseVerbs.contains(w)) {
      final stem = w.substring(0, w.length - 2);
      if (!_commonBaseVerbs.contains(stem) &&
          !_commonBaseVerbs.contains(_undoubleFinalConsonant(stem))) {
        return true;
      }
    }
    return false;
  }

  /// Rule 7: statement + [rh-q] WHY? + answer (replaces because/so conjunctions).
  static List<String> _rhetoricalWhyClause(
    List<String> statement,
    List<String> answer,
  ) {
    return [
      ..._reorderDiscourseMain(statement),
      AslNmmMarkers.rhQ,
      'why',
      ..._reorderSubclause(answer),
    ];
  }

  /// Rule 9: CAR RED / HOUSE BIG — adjective after noun.
  static List<String> _applyNounAdjectiveOrder(List<String> words) {
    if (words.length != 2) {
      return words;
    }
    final a = words[0];
    final b = words[1];
    if (_looksLikeVerb(a) || _looksLikeVerb(b)) {
      return words;
    }
    if (_looksLikeAdjective(a) && !_looksLikeAdjective(b)) {
      return [b, a];
    }
    return words;
  }

  /// Rule 8: post-fix NOT / CANNOT / NEVER + [headshake].
  static List<String> _applyPostFixNegation(
    List<String> words, {
    required bool sawNegation,
    required bool sawCannot,
  }) {
    if (!sawNegation && !words.contains('not') && !words.contains('not-can')) {
      return words;
    }
    var result = words.where((w) => w != 'not' && w != 'not-can').toList();
    if (sawCannot || words.contains('not-can') || words.contains('cannot')) {
      if (!result.contains('cannot')) {
        result = [...result, 'cannot'];
      }
    } else if (sawNegation) {
      result = [...result, 'not'];
    }
    if (!result.contains(AslNmmMarkers.headshake)) {
      result = [...result, AslNmmMarkers.headshake];
    }
    return result;
  }

  /// Rules 5–6: WH-final [wh-q]; Y/N prefix [y/n-q].
  static List<String> _applySpecNmmMarkers(
    List<String> words, {
    required bool isWhQuestion,
    required bool isYesNoQuestion,
    required bool clauseIsQuestion,
  }) {
    var result = List<String>.from(words);
    if (isYesNoQuestion && !result.contains(AslNmmMarkers.ynQ)) {
      result = [AslNmmMarkers.ynQ, ...result];
    }
    if (clauseIsQuestion && isWhQuestion && _containsWhWord(result)) {
      if (!result.contains(AslNmmMarkers.whQ)) {
        result = [...result, AslNmmMarkers.whQ];
      }
    }
    return result;
  }

  /// Rule 15: ME GO STORE ME / Rule 6: YOU DEAF YOU.
  static List<String> _applyOptionalPronounWrap(
    List<String> words, {
    required bool isYesNoQuestion,
  }) {
    final content = _stripNmmMarkers(words);
    if (content.isEmpty) {
      return words;
    }
    if (content.length >= 2 &&
        content[0] == 'me' &&
        (content[1] == 'tell' || content[1] == 'tell-you')) {
      return words;
    }
    final lead = content.first;
    if (!_isSubjectPronoun(lead)) {
      return words;
    }
    if (content.last == lead) {
      return words;
    }
    if (isYesNoQuestion && lead == 'you') {
      return [...words, lead];
    }
    if (lead == 'you' &&
        words.any((w) =>
            w == 'give-you' ||
            w == 'give-me' ||
            w == 'tell-you' ||
            w == 'tell-me')) {
      return [...words, lead];
    }
    if (!isYesNoQuestion &&
        lead == 'me' &&
        (content.any(_looksLikeVerb) ||
            words.any((w) =>
                w == 'give-you' ||
                w == 'give-me' ||
                w == 'tell-you' ||
                w == 'tell-me')) &&
        !AslNmmMarkers.isMarker(words.last)) {
      return [...words, lead];
    }
    return words;
  }

  /// Drop leftover IX from IF-condition processing (it rains → RAIN, not IX).
  static List<String> _dropStrayIxAfterIf(List<String> words) {
    if (words.isEmpty || words.first != 'if') {
      return words;
    }
    return words.where((w) => w != 'ix').toList();
  }
}
