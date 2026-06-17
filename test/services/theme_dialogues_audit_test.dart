import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

/// Grammar-shift heuristics aligned with pedagogical ASL Fix glosses.
bool _reasonBeforeMain(List<String> glosses) {
  final reasonIdx = glosses.indexOf('REASON');
  if (reasonIdx < 0) return true;
  // Main verb-ish tokens after REASON should not precede REASON.
  const mainVerbs = {
    'WANT', 'PREFER', 'NEED', 'MISS', 'RETURN', 'BUY', 'DRINK', 'EAT',
    'PRINT', 'SIT', 'WAIT', 'LEAVE', 'GO', 'SEE', 'TAKE', 'SWALLOW',
  };
  for (var i = 0; i < reasonIdx; i++) {
    if (mainVerbs.contains(glosses[i])) return false;
  }
  return true;
}

bool _ifAfterCondition(List<String> glosses) {
  final ifIdx = glosses.indexOf('IF');
  if (ifIdx < 0) return true;
  return ifIdx > 0;
}

bool _willAtEndWhenConditional(List<String> glosses) {
  if (!glosses.contains('WILL') || !glosses.contains('IF')) return true;
  return glosses.last == 'WILL' || glosses.indexOf('WILL') == glosses.length - 1;
}

bool _finishForPast(String english, List<String> glosses) {
  final pastHints = RegExp(
    r'\b(missed|burned|dropped|brought|sat|wore|went|left|returned|'
    r'bought|lost|refused|damaged|confiscated|smashed|cracked|scraped|'
    r'crushed|tore|found|wrapped|mislabeled|postponed|cleaned|hit)\b',
    caseSensitive: false,
  );
  if (!pastHints.hasMatch(english)) return true;
  return glosses.contains('FINISH');
}

int _grammarScore(String sentence, List<String> glosses) {
  var score = 0;
  if (_reasonBeforeMain(glosses)) score++;
  if (_ifAfterCondition(glosses)) score++;
  if (_willAtEndWhenConditional(glosses)) score++;
  if (_finishForPast(sentence, glosses)) score++;
  return score;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('theme dialogues audit report', () {
    final sentences = File('test/fixtures/theme_dialogues_sentences.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    var hidden = 0;
    var withGloss = 0;
    var fingerspell3 = 0;
    var grammarPerfect = 0;
    var grammarPartial = 0;
    var grammarFail = 0;

    final hiddenSamples = <String>[];
    final failSamples = <String>[];
    final themeScores = <String, List<int>>{
      'coffee': [],
      'hospital': [],
      'airport': [],
      'shopping': [],
      'transit': [],
    };

    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final glosses =
          SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();

      final theme = i < 15
          ? 'coffee'
          : i < 30
          ? 'hospital'
          : i < 45
          ? 'airport'
          : i < 60
          ? 'shopping'
          : 'transit';

      if (glosses.isEmpty) {
        hidden++;
        hiddenSamples.add('D${i + 1}: $sentence');
        continue;
      }

      withGloss++;
      final letters = glosses.where((g) => g.length == 1).length;
      if (letters >= 3) {
        fingerspell3++;
      }

      final gScore = _grammarScore(sentence, glosses);
      themeScores[theme]!.add(gScore);
      if (gScore == 4) {
        grammarPerfect++;
      } else if (gScore >= 2) {
        grammarPartial++;
      } else {
        grammarFail++;
        if (failSamples.length < 15) {
          failSamples.add('D${i + 1}: $sentence\n  GL: ${glosses.join(' ')}');
        }
      }

      // ignore: avoid_print
      print('D${i + 1}: $sentence');
      // ignore: avoid_print
      print('  GL: ${glosses.join(' ')}');
      // ignore: avoid_print
      print('  grammar: $gScore/4');
      // ignore: avoid_print
      print('');
    }

    final n = sentences.length;
    // ignore: avoid_print
    print('=== THEME DIALOGUES AUDIT ($n) ===');
    // ignore: avoid_print
    print('Coverage: $withGloss/$n');
    // ignore: avoid_print
    print('Hidden: $hidden');
    // ignore: avoid_print
    print('Fingerspell 3+: $fingerspell3');
    // ignore: avoid_print
    print(
      'Grammar heuristics: perfect=$grammarPerfect partial=$grammarPartial fail=$grammarFail',
    );
    for (final entry in themeScores.entries) {
      final scores = entry.value;
      if (scores.isEmpty) continue;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      // ignore: avoid_print
      print('  ${entry.key}: avg grammar ${avg.toStringAsFixed(1)}/4');
    }
    if (hiddenSamples.isNotEmpty) {
      // ignore: avoid_print
      print('--- HIDDEN ---');
      for (final s in hiddenSamples) {
        // ignore: avoid_print
        print('  $s');
      }
    }
    if (failSamples.isNotEmpty) {
      // ignore: avoid_print
      print('--- GRAMMAR FAIL SAMPLES ---');
      for (final s in failSamples) {
        // ignore: avoid_print
        print('  $s');
      }
    }

    expect(hidden, 0);
    expect(withGloss, n);
  });
}
