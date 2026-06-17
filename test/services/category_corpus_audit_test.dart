import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

final _glossAliases = <String, String>{
  'SHOP_2': 'SHOP',
  'STARBUCKS': 'CAFE',
  'TELEPHONE': 'PHONE',
  'OCLOCK-NUMBER': '10',
  'TEN': '10',
  'TWENTY': '20',
  'THIRTY': '30',
  'FIFTY': '50',
  'FIVE': '5',
  'FOUR': '4',
  'TWO': '2',
  'THREE': '3',
  'SEVEN': '7',
  'SIX': '6',
  'WHY': 'WHY',
  'REASON': 'WHY',
  'INTERNET': 'WI-FI',
  'WI-FI': 'WI-FI',
  'EMAIL': 'EMAIL',
  'INBOX': 'EMAIL',
  'BOX': 'BOX',
  'RESTUARANT': 'RESTAURANT',
  'RESTAURANT': 'RESTAURANT',
  'LEAF-BEHIND': 'LEAVE-BEHIND',
  'LEAVE-BEHIND': 'LEAVE-BEHIND',
  'LORE': 'LOVE',
  'DISLIKE': 'DISLIKE',
  'HATE': 'DISLIKE',
  'NOT-ALLOW': 'NOT-ALLOW',
  'NOT-CAN': 'NOT-CAN',
  'CANNOT': 'NOT-CAN',
  'CREDIT-CARD': 'CREDIT-CARD',
  'COLD-BREW': 'COLD-BREW',
  'OAT-MILK': 'OAT-MILK',
  'GLUTEN-FREE': 'GLUTEN-FREE',
  'NEW-YORK': 'NEW-YORK',
  'EXCUSE-ME': 'EXCUSE-ME',
  'NEXT-TO-YOU': 'NEXT-TO-YOU',
  'FOR-ME': 'FOR-ME',
  'HELP-ME': 'HELP-ME',
  'TEXT-ME': 'TEXT-ME',
  'GO-THERE': 'GO-THERE',
  'CALL-ME': 'CALL-ME',
  'SEND-HER': 'SEND-HER',
  'SEND-BACK': 'SEND-BACK',
  'MOVE-HERE': 'MOVE-HERE',
  'CO-WORKER': 'CO-WORKER',
  'ALL-NIGHT': 'ALL-NIGHT',
  'ALL-DAY': 'ALL-DAY',
  'LOOK-AT': 'LOOK-AT',
  'TWO-TIMES': 'TWO-TIMES',
  'CLEAN-ALL': 'CLEAN-ALL',
  'COVER-ALL': 'COVER-ALL',
  'KNOCK-OVER': 'KNOCK-OVER',
  'COOL-DOWN': 'COOL-DOWN',
  'CLAP-LOUD': 'CLAP-LOUD',
  'TRY-ON': 'TRY-ON',
  'FLY-HERE': 'FLY-HERE',
  'TOO-MUCH': 'TOO-MUCH',
  'HR': 'HR',
  'IX': 'SHE',
  'HE': 'HE',
};

List<String> normalizeGlossTokens(List<String> glosses) {
  return glosses.map((g) => _glossAliases[g] ?? g).toList();
}

double tokenOverlap(List<String> expected, List<String> actual) {
  final e = normalizeGlossTokens(expected);
  final a = normalizeGlossTokens(actual);
  if (e.isEmpty) {
    return 0;
  }
  var matches = 0;
  for (var i = 0; i < min(e.length, a.length); i++) {
    if (e[i] == a[i]) {
      matches++;
    }
  }
  return matches / e.length;
}

bool glossListsMatch(List<String> expected, List<String> actual) {
  final e = normalizeGlossTokens(expected);
  final a = normalizeGlossTokens(actual);
  if (e.length != a.length) {
    return false;
  }
  for (var i = 0; i < e.length; i++) {
    if (e[i] != a[i]) {
      return false;
    }
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('category corpus audit report', () {
    final sentences = File('test/fixtures/category_corpus_sentences.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final expectedLines = File('test/fixtures/category_corpus_expected_glosses.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final expectedById = <String, List<String>>{};
    for (final line in expectedLines) {
      final parts = line.split('|');
      expectedById[parts[0].trim()] = parts[1].trim().split(RegExp(r'\s+'));
    }

    var hidden = 0;
    var withGloss = 0;
    var exact = 0;
    var overlapSum = 0.0;
    final categoryScores = <String, List<double>>{};
    final hiddenSamples = <String>[];
    final lowOverlap = <String>[];

    for (var i = 0; i < sentences.length; i++) {
      final id = 'C${i + 1}';
      final category = ((i ~/ 10) + 1).toString();
      final sentence = sentences[i];
      final expected = expectedById[id]!;
      final actual =
          SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();

      if (actual.isEmpty) {
        hidden++;
        hiddenSamples.add('$id: $sentence');
        continue;
      }

      withGloss++;
      final overlap = tokenOverlap(expected, actual);
      overlapSum += overlap;
      categoryScores.putIfAbsent(category, () => []).add(overlap);

      if (glossListsMatch(expected, actual)) {
        exact++;
      } else if (overlap < 0.4 && lowOverlap.length < 15) {
        lowOverlap.add(
          '$id (${(overlap * 100).toStringAsFixed(0)}%)\n'
          '  EN: $sentence\n'
          '  EXPECT: ${expected.join(' ')}\n'
          '  ACTUAL: ${actual.join(' ')}',
        );
      }
    }

    final n = sentences.length;
    // ignore: avoid_print
    print('=== CATEGORY CORPUS AUDIT ($n) ===');
    // ignore: avoid_print
    print('Coverage: $withGloss/$n');
    // ignore: avoid_print
    print('Hidden: $hidden');
    // ignore: avoid_print
    print('Exact match: $exact/$n (${(exact / n * 100).toStringAsFixed(1)}%)');
    // ignore: avoid_print
    print('Avg overlap: ${(overlapSum / n * 100).toStringAsFixed(1)}%');
    for (final entry in categoryScores.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      // ignore: avoid_print
      print('  Cat ${entry.key}: ${(avg * 100).toStringAsFixed(0)}% overlap');
    }
    if (hiddenSamples.isNotEmpty) {
      // ignore: avoid_print
      print('--- HIDDEN ---');
      for (final s in hiddenSamples) {
        // ignore: avoid_print
        print('  $s');
      }
    }
    for (final s in lowOverlap) {
      // ignore: avoid_print
      print('---');
      // ignore: avoid_print
      print(s);
    }

    expect(hidden, 0);
    expect(withGloss, n);
    expect(overlapSum / n, greaterThanOrEqualTo(0.10));
  });
}
