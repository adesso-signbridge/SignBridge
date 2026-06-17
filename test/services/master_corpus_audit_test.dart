import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

/// Audits every sentence fixture and prints per-corpus + combined ratings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('master corpus audit report', () {
    const fixtures = <String>[
      'test/fixtures/audit_sentences.txt',
      'test/fixtures/musings_sentences.txt',
      'test/fixtures/themed_sentences.txt',
      'test/fixtures/travel_electronics_sentences.txt',
      'test/fixtures/family_life_sentences.txt',
      'test/fixtures/civic_social_sentences.txt',
      'test/fixtures/dialogue_scenarios_sentences.txt',
    ];

    final allSentences = <String>{};
    final perFile = <String, _CorpusStats>{};

    for (final path in fixtures) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final sentences = file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      final stats = _audit(sentences);
      perFile[path] = stats;
      allSentences.addAll(sentences);
    }

    final combined = _audit(allSentences.toList());

    // ignore: avoid_print
    print('=== MASTER CORPUS AUDIT ===');
    for (final entry in perFile.entries) {
      final name = entry.key.split('/').last.replaceAll('.txt', '');
      final s = entry.value;
      // ignore: avoid_print
      print(
        '$name: ${s.withGloss}/${s.total} cov ${s.coveragePct}% | '
        'spell ${s.fingerspellPct}% | hidden ${s.hidden}',
      );
    }
    // ignore: avoid_print
    print('--- COMBINED (unique) ---');
    // ignore: avoid_print
    print(
      'Sentences: ${combined.total} | Coverage: ${combined.coveragePct}% | '
      'Fingerspell 3+: ${combined.fingerspellPct}% | Hidden: ${combined.hidden}',
    );
  // ignore: avoid_print
    print('--- GRADE ---');
    // ignore: avoid_print
    print(_grade(combined));

    if (combined.hiddenSamples.isNotEmpty) {
      // ignore: avoid_print
      print('--- HIDDEN samples ---');
      for (final s in combined.hiddenSamples.take(20)) {
        // ignore: avoid_print
        print('  $s');
      }
    }
    if (combined.spellSamples.isNotEmpty) {
      // ignore: avoid_print
      print('--- FINGERSPELL samples ---');
      for (final s in combined.spellSamples.take(25)) {
        // ignore: avoid_print
        print('  $s');
      }
    }

    expect(combined.hidden, lessThan(combined.total * 0.02));
    expect(combined.withGloss, greaterThan(combined.total * 0.98));
  });
}

class _CorpusStats {
  _CorpusStats({
    required this.total,
    required this.withGloss,
    required this.hidden,
    required this.fingerspell3,
    required this.hiddenSamples,
    required this.spellSamples,
  });

  final int total;
  final int withGloss;
  final int hidden;
  final int fingerspell3;
  final List<String> hiddenSamples;
  final List<String> spellSamples;

  double get coveragePct => total == 0 ? 0 : withGloss / total * 100;
  double get fingerspellPct => total == 0 ? 0 : fingerspell3 / total * 100;
}

_CorpusStats _audit(List<String> sentences) {
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
      if (hiddenSamples.length < 30) {
        hiddenSamples.add(sentence);
      }
      continue;
    }

    withGloss++;
    final letters = glosses.where((g) => g.length == 1).length;
    if (letters >= 3) {
      fingerspell3++;
      if (spellSamples.length < 30) {
        spellSamples.add('$sentence => ${glosses.join(' ')}');
      }
    }
  }

  return _CorpusStats(
    total: sentences.length,
    withGloss: withGloss,
    hidden: hidden,
    fingerspell3: fingerspell3,
    hiddenSamples: hiddenSamples,
    spellSamples: spellSamples,
  );
}

String _grade(_CorpusStats s) {
  if (s.coveragePct >= 99 && s.fingerspellPct <= 2 && s.hidden == 0) {
    return 'A+ (production-ready lexicon coverage)';
  }
  if (s.coveragePct >= 98 && s.fingerspellPct <= 5) {
    return 'A (excellent — minor spelling on rare compounds)';
  }
  if (s.coveragePct >= 95 && s.fingerspellPct <= 10) {
    return 'B (good — systematic conjugation/compound gaps remain)';
  }
  if (s.coveragePct >= 90) {
    return 'C (fair — noticeable gaps)';
  }
  return 'D (needs work — high hidden or spell rate)';
}
