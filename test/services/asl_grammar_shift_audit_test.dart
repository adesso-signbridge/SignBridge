import 'dart:io';

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

  test('grammar shift audit report', () {
    final sentences = File('test/fixtures/asl_grammar_shift_sentences.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    var hidden = 0;
    var withGloss = 0;
    var fingerspell3 = 0;
    final hiddenSamples = <String>[];
    final spellSamples = <String>[];

    for (final sentence in sentences) {
      final glosses =
          SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();

      if (glosses.isEmpty) {
        hidden++;
        hiddenSamples.add(sentence);
        continue;
      }
      withGloss++;
      final letters = glosses.where((g) => g.length == 1).length;
      if (letters >= 3) {
        fingerspell3++;
        spellSamples.add('$sentence => ${glosses.join(' ')}');
      }
      // ignore: avoid_print
      print('EN: $sentence');
      // ignore: avoid_print
      print('GL: ${glosses.join(' ')}');
      // ignore: avoid_print
      print('');
    }

    final n = sentences.length;
    // ignore: avoid_print
    print('=== GRAMMAR SHIFT AUDIT ($n) ===');
    // ignore: avoid_print
    print('Coverage: $withGloss/$n');
    // ignore: avoid_print
    print('Hidden: $hidden');
    // ignore: avoid_print
    print('Fingerspell 3+: $fingerspell3');

    expect(hidden, 0);
    expect(withGloss, n);
  });
}
