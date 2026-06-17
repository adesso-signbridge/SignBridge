import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

/// Benchmark: 1000 pronoun + dictionary word pairs through ASL gloss pipeline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('1000 different words through gloss pipeline', () async {
    final words = await _sampleDictionaryWords(1000);
    expect(words.length, 1000);

    final pronouns = [
      'you',
      'they',
      'he',
      'she',
      'we',
      'i',
      'it',
      'our',
      'your',
      'me',
      'us',
      'them',
    ];

    var hidden = 0;
    var pronounOnly = 0;
    var normalPair = 0;
    var fingerspelled = 0;
    var threePlusTokens = 0;

    final hiddenSamples = <String>[];
    final spellSamples = <String>[];
    final normalSamples = <String>[];

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final pronoun = pronouns[i % pronouns.length];
      final phrase = '$pronoun $word';
      final sequence = SignGlossMapper.signSequence(phrase, 'ENG');
      final glosses = sequence.map((t) => t.gloss).toList();

      if (sequence.isEmpty) {
        hidden++;
        if (hiddenSamples.length < 10) {
          hiddenSamples.add(phrase);
        }
        continue;
      }

      final letterCount = glosses.where((g) => g.length == 1).length;
      // Name-style spelling only after MY/YOUR NAME in real intros — not vocab drills.
      if (letterCount >= 3 && glosses.contains('NAME')) {
        fingerspelled++;
        if (spellSamples.length < 8) {
          spellSamples.add('$phrase => ${glosses.join(' ')}');
        }
      } else if (glosses.length == 1) {
        pronounOnly++;
      } else if (glosses.length == 2) {
        normalPair++;
        if (normalSamples.length < 8) {
          normalSamples.add('$phrase => ${glosses.join(' ')}');
        }
      } else {
        threePlusTokens++;
      }
    }

    var singleHidden = 0;
    for (final word in words) {
      if (SignGlossMapper.signSequence(word, 'ENG').isEmpty) {
        singleHidden++;
      }
    }

    final shown = 1000 - hidden;
    final report = [
      '=== 1000-word ASL gloss benchmark ===',
      'Words: evenly spaced sample from ${EnglishLexicon.loadedWordCount} dictionary entries',
      '',
      'Pronoun + word (12 pronouns rotated):',
      '  Chip shows gloss: $shown / 1000 (${(shown / 10).toStringAsFixed(1)}%)',
      '  Hidden (Signing: ...): $hidden / 1000',
      '  Normal 2-sign gloss (e.g. YOU WORD): $normalPair',
      '  Pronoun only (word dropped, e.g. YOU): $pronounOnly',
      '  Name-style fingerspelling (3+ letters): $fingerspelled',
      '  Other multi-token: $threePlusTokens',
      '',
      'Single word alone:',
      '  Glossed: ${1000 - singleHidden} / 1000',
      '  Hidden: $singleHidden / 1000',
      '',
      'Sample normal pairs:',
      ...normalSamples,
      '',
      'Sample fingerspelled (MY/YOUR/ME name-intro path):',
      ...spellSamples,
      if (hiddenSamples.isNotEmpty) 'Sample hidden:',
      ...hiddenSamples,
    ].join('\n');

    // ignore: avoid_print
    print(report);

    expect(fingerspelled, 0);
    expect(hidden, lessThan(50));
  });
}

Future<List<String>> _sampleDictionaryWords(int count) async {
  final path = '${Directory.current.path}/assets/lexicon/english_dictionary.txt';
  final lines = await File(path).readAsLines();
  final stride = lines.length ~/ count;
  final words = <String>[];
  for (var i = 0; i < count; i++) {
    words.add(lines[i * stride].trim().toLowerCase());
  }
  return words;
}
