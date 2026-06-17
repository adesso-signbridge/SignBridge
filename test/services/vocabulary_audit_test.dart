import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

/// Audit gloss coverage for curriculum / vocabulary sentence list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('vocabulary sentence audit report', () {
    final path = 'test/fixtures/audit_sentences.txt';
    final lines = File(path).readAsLinesSync();
    final sentences = lines.where((l) => l.trim().isNotEmpty).toList();
    expect(sentences.length, greaterThan(800));

    var hidden = 0;
    var withGloss = 0;
    var singleLetterHeavy = 0;
    var oneToken = 0;
    var twoTokens = 0;
    var threePlus = 0;

    final hiddenSamples = <String>[];
    final spellSamples = <String>[];
    final shortSamples = <String>[];

    for (final sentence in sentences) {
      final sequence = SignGlossMapper.signSequence(sentence, 'ENG');
      final glosses = sequence.map((t) => t.gloss).toList();

      if (sequence.isEmpty) {
        hidden++;
        if (hiddenSamples.length < 40) {
          hiddenSamples.add(sentence);
        }
        continue;
      }

      withGloss++;
      final letters = glosses.where((g) => g.length == 1).length;
      if (letters >= 3) {
        singleLetterHeavy++;
        if (spellSamples.length < 25) {
          spellSamples.add('$sentence => ${glosses.join(' ')}');
        }
      }

      if (glosses.length == 1) {
        oneToken++;
        if (shortSamples.length < 15) {
          shortSamples.add('$sentence => ${glosses.join(' ')}');
        }
      } else if (glosses.length == 2) {
        twoTokens++;
      } else {
        threePlus++;
      }
    }

    final coverage = (withGloss / sentences.length * 100).toStringAsFixed(1);
    final hiddenPct = (hidden / sentences.length * 100).toStringAsFixed(1);

    // ignore: avoid_print
    print('=== VOCABULARY AUDIT (${sentences.length} sentences) ===');
    // ignore: avoid_print
    print('Chip coverage: $withGloss/${sentences.length} ($coverage%)');
    // ignore: avoid_print
    print('Hidden (empty): $hidden ($hiddenPct%)');
    // ignore: avoid_print
    print('Token counts: 1=$oneToken 2=$twoTokens 3+=$threePlus');
    // ignore: avoid_print
    print('Heavy fingerspell (3+ letters): $singleLetterHeavy');
  // ignore: avoid_print
    print('--- Hidden samples (first ${hiddenSamples.length}) ---');
    for (final s in hiddenSamples) {
      // ignore: avoid_print
      print('  HIDE: $s');
    }
    // ignore: avoid_print
    print('--- Fingerspell-heavy samples ---');
    for (final s in spellSamples) {
      // ignore: avoid_print
      print('  SPELL: $s');
    }
    // ignore: avoid_print
    print('--- Single-token samples ---');
    for (final s in shortSamples) {
      // ignore: avoid_print
      print('  ONE: $s');
    }

    // Soft gate: most curriculum sentences should produce a chip gloss.
    expect(withGloss, greaterThan(sentences.length * 0.85));
  });
}
