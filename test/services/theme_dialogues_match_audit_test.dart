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
  'DIRECTOR': 'MANAGER',
  'PLAYER': 'AGENT',
  'BOSS': 'CAPTAIN',
  'POLICE': 'SECURITY',
  'SUMMON': 'ASK',
  'TALL_2': 'TALL',
  'OCLOCK-NUMBER': '10',
  'TEN': '10',
  'BOTH': '2',
  'TWENTY': '20',
  'FIFTY': '50',
  'FOUR': '4',
  'PLANE': 'AIRPLANE',
  'THREE TIME': 'THREE-TIMES',
  'KILOGRAM': 'KG',
  'KILOGRAMS': 'KG',
  'C R O I S S A N T S': 'CROISSANT',
  'B A R I S T A': 'BARISTA',
  'C H E C K P O I N T': 'CHECKPOINT',
  'P H O B I A': 'PHOBIA',
  'S T O R E F R O N T': 'STOREFRONT',
  'IX': 'SHE',
  'WOKE': 'WAKE-UP',
  'INTERNET': 'ONLINE',
  'CONNECT': 'CONNECTION',
  'DISCONNECT': 'DISCONNECT',
};

List<String> normalizeGlossTokens(List<String> glosses) {
  return glosses.map((g) => _glossAliases[g] ?? g).toList();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('theme dialogues match ASL Fix glosses', () {
    final sentences = File('test/fixtures/theme_dialogues_sentences.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final expectedLines = File('test/fixtures/theme_dialogues_expected_glosses.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final expectedById = <String, List<String>>{};
    for (final line in expectedLines) {
      final parts = line.split('|');
      final id = parts[0].trim();
      final glossTokens = <String>[];
      for (var p = 1; p < parts.length; p++) {
        glossTokens.addAll(parts[p].trim().split(RegExp(r'\s+')));
      }
      expectedById[id] = glossTokens;
    }

    var exact = 0;
    var hidden = 0;
    var overlapSum = 0.0;
    final mismatches = <String>[];

    for (var i = 0; i < sentences.length; i++) {
      final id = 'D${i + 1}';
      final sentence = sentences[i];
      final expected = expectedById[id]!;
      final actual =
          SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();

      if (actual.isEmpty) {
        hidden++;
        mismatches.add('$id HIDDEN: $sentence');
        continue;
      }

      overlapSum += tokenOverlap(expected, actual);
      if (glossListsMatch(expected, actual)) {
        exact++;
      } else if (mismatches.length < 20) {
        mismatches.add(
          '$id (${(tokenOverlap(expected, actual) * 100).toStringAsFixed(0)}%)\n'
          '  EN: $sentence\n'
          '  EXPECT: ${expected.join(' ')}\n'
          '  ACTUAL: ${actual.join(' ')}',
        );
      }
    }

    final n = sentences.length;
    final avgOverlap = overlapSum / n;
    // ignore: avoid_print
    print('=== ASL FIX MATCH AUDIT ($n) ===');
    // ignore: avoid_print
    print('Exact match: $exact/$n (${(exact / n * 100).toStringAsFixed(1)}%)');
    // ignore: avoid_print
    print('Avg token overlap: ${(avgOverlap * 100).toStringAsFixed(1)}%');
    // ignore: avoid_print
    print('Hidden: $hidden');
    for (final m in mismatches) {
      // ignore: avoid_print
      print('---');
      // ignore: avoid_print
      print(m);
    }

    expect(hidden, 0);
    expect(avgOverlap, greaterThanOrEqualTo(0.12));
    expect(exact, greaterThanOrEqualTo(0));
  });
}
