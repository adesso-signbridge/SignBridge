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

  test('musings audit report', () {
    final sentences = File('test/fixtures/musings_sentences.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    expect(sentences.length, greaterThan(100));

    var hidden = 0;
    var withGloss = 0;
    var fingerspell3 = 0;
    var subjectLast = 0;

    final hiddenSamples = <String>[];
    final spellSamples = <String>[];
    final goodSamples = <String>[];

    for (final sentence in sentences) {
      final glosses =
          SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();

      if (glosses.isEmpty) {
        hidden++;
        if (hiddenSamples.length < 30) {
          hiddenSamples.add(sentence);
        }
        continue;
      }

      withGloss++;
      final letters = glosses.where((g) => g.length == 1).length;
      if (letters >= 3) {
        fingerspell3++;
        if (spellSamples.length < 20) {
          spellSamples.add('$sentence => ${glosses.join(' ')}');
        }
      } else if (goodSamples.length < 15) {
        goodSamples.add('$sentence => ${glosses.join(' ')}');
      }

      final subs = {'ME', 'YOU', 'IX', 'WE', 'THEY', 'YOUR', 'THEIR', 'MY'};
      if (glosses.length >= 2 &&
          subs.contains(glosses.last) &&
          !subs.contains(glosses.first)) {
        subjectLast++;
      }
    }

    final n = sentences.length;
  // ignore: avoid_print
    print('=== MUSINGS AUDIT ($n unique sentences) ===');
    // ignore: avoid_print
    print(
      'Coverage: $withGloss/$n (${(withGloss / n * 100).toStringAsFixed(1)}%)',
    );
    // ignore: avoid_print
    print('Hidden: $hidden');
    // ignore: avoid_print
    print(
      'Fingerspell 3+: $fingerspell3 (${(fingerspell3 / n * 100).toStringAsFixed(1)}%)',
    );
    // ignore: avoid_print
    print(
      'Subject-last: $subjectLast (${(subjectLast / n * 100).toStringAsFixed(1)}%)',
    );
    // ignore: avoid_print
    print('--- HIDDEN ---');
    for (final s in hiddenSamples) {
      // ignore: avoid_print
      print('  $s');
    }
    // ignore: avoid_print
    print('--- FINGERSPELL ---');
    for (final s in spellSamples) {
      // ignore: avoid_print
      print('  $s');
    }
    // ignore: avoid_print
    print('--- CLEAN ---');
    for (final s in goodSamples) {
      // ignore: avoid_print
      print('  $s');
    }

    expect(hidden, lessThan(n * 0.15));
    expect(withGloss, greaterThan(n * 0.85));
  });
}
