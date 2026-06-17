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

  test('civic social audit report', () {
    final sentences = File('test/fixtures/civic_social_sentences.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(sentences.length, 400);

    var hidden = 0;
    var withGloss = 0;
    var fingerspell3 = 0;
    final spellSamples = <String>[];

    for (final sentence in sentences) {
      final glosses =
          SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();
      if (glosses.isEmpty) {
        hidden++;
        continue;
      }
      withGloss++;
      final letters = glosses.where((g) => g.length == 1).length;
      if (letters >= 3) {
        fingerspell3++;
        spellSamples.add('$sentence => ${glosses.join(' ')}');
      }
    }

    final n = sentences.length;
    // ignore: avoid_print
    print('=== CIVIC/SOCIAL AUDIT ($n) ===');
    // ignore: avoid_print
    print('Fingerspell 3+: $fingerspell3 (${(fingerspell3 / n * 100).toStringAsFixed(1)}%)');
    for (final s in spellSamples) {
      // ignore: avoid_print
      print('  $s');
    }

    expect(hidden, 0);
    expect(withGloss, n);
    expect(fingerspell3, lessThan(n * 0.02));
  });
}
