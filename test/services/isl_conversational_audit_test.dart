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

  test('ISL conversational sets audit', () {
    final fixture = File('test/fixtures/isl_conversational_sets.txt');
    final lines = fixture.readAsLinesSync();
    var total = 0;
    var hidden = 0;
    var exact = 0;
    var partial = 0;
    final failures = <String>[];

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) {
        continue;
      }
      final parts = line.split('|');
      if (parts.length < 3) {
        continue;
      }
      total++;
      final lang = parts[0];
      final native = parts[1];
      final expected = parts[2].trim().split(RegExp(r'\s+'));

      final actual = SignGlossMapper.signSequence(native, lang)
          .map((t) => t.gloss)
          .toList();

      if (actual.isEmpty) {
        hidden++;
        failures.add('HIDDEN [$lang] $native');
        continue;
      }

      if (actual.join(' ') == expected.join(' ')) {
        exact++;
      } else {
        final overlap = expected.where(actual.contains).length;
        if (overlap >= expected.length * 0.5) {
          partial++;
        }
        failures.add(
          '[$lang] $native\n  expected: ${expected.join(" ")}\n  actual:   ${actual.join(" ")}',
        );
      }
    }

    // ignore: avoid_print
    print(
      'ISL conversational audit: $exact/$total exact, '
      '$partial partial, $hidden hidden (${lines.length} lines)',
    );
    if (failures.isNotEmpty && failures.length <= 30) {
      for (final f in failures) {
        // ignore: avoid_print
        print(f);
      }
    } else if (failures.length > 30) {
      for (final f in failures.take(25)) {
        // ignore: avoid_print
        print(f);
      }
      // ignore: avoid_print
      print('... and ${failures.length - 25} more');
    }

    expect(hidden, 0, reason: '${hidden} sentences produced no gloss');
  });
}
