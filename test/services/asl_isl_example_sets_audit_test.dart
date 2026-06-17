import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';

/// Unified audit: ASL (ENG) and ISL (HI/TA/ML) against curated example sets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
  });

  test('ASL and ISL example sets audit report', () {
    final reports = <_AuditReport>[];

    reports.add(_auditIslConversational());
    reports.add(_auditIslGrammarExamples());
    reports.add(_auditAslCategoryCorpus());
    reports.add(_auditAslGrammarShift());
    reports.add(_auditAslSpecExamples());

    // ignore: avoid_print
    print('\n${'=' * 60}');
    // ignore: avoid_print
    print('ASL + ISL EXAMPLE SETS AUDIT');
    // ignore: avoid_print
    print('=' * 60);
    for (final r in reports) {
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('── ${r.name} (${r.system}) ──');
      // ignore: avoid_print
      print('Total: ${r.total}');
      // ignore: avoid_print
      print('Coverage (chip not empty): ${r.withGloss}/${r.total}');
      // ignore: avoid_print
      print('Hidden: ${r.hidden}');
      if (r.exactMatch != null) {
        // ignore: avoid_print
        print(
          'Exact gloss match: ${r.exactMatch}/${r.total} '
          '(${_pct(r.exactMatch!, r.total)}%)',
        );
      }
      if (r.avgOverlap != null) {
        // ignore: avoid_print
        print('Avg token overlap: ${(r.avgOverlap! * 100).toStringAsFixed(1)}%');
      }
      if (r.fingerspell3Plus != null) {
        // ignore: avoid_print
        print('Heavy fingerspell (3+ letters): ${r.fingerspell3Plus}');
      }
      if (r.failures.isNotEmpty) {
        // ignore: avoid_print
        print('Sample mismatches (max 8):');
        for (final f in r.failures.take(8)) {
          // ignore: avoid_print
          print('  $f');
        }
        if (r.failures.length > 8) {
          // ignore: avoid_print
          print('  ... and ${r.failures.length - 8} more');
        }
      }
    }

    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('── SUMMARY ──');
    for (final r in reports) {
      final exact = r.exactMatch != null
          ? '${r.exactMatch}/${r.total} exact'
          : r.avgOverlap != null
              ? 'overlap ${(r.avgOverlap! * 100).toStringAsFixed(0)}%'
              : 'coverage only';
      // ignore: avoid_print
      print(
        '${r.system} ${r.name}: ${r.withGloss}/${r.total} covered, '
        '$exact, ${r.hidden} hidden',
      );
    }

    expect(
      reports.where((r) => r.name.contains('ISL Conversational')).first.exactMatch,
      300,
    );
    expect(
      reports.where((r) => r.name.contains('ISL Grammar')).first.exactMatch,
      18,
    );
    expect(
      reports.where((r) => r.name.contains('ISL Conversational')).first.hidden,
      0,
    );
  });
}

class _AuditReport {
  _AuditReport({
    required this.name,
    required this.system,
    required this.total,
    required this.withGloss,
    required this.hidden,
    this.exactMatch,
    this.avgOverlap,
    this.fingerspell3Plus,
    this.failures = const [],
  });

  final String name;
  final String system;
  final int total;
  final int withGloss;
  final int hidden;
  final int? exactMatch;
  final double? avgOverlap;
  final int? fingerspell3Plus;
  final List<String> failures;
}

_AuditReport _auditIslConversational() {
  final lines = File('test/fixtures/isl_conversational_sets.txt').readAsLinesSync();
  var total = 0;
  var withGloss = 0;
  var hidden = 0;
  var exact = 0;
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
    final actual =
        SignGlossMapper.signSequence(native, lang).map((t) => t.gloss).toList();

    if (actual.isEmpty) {
      hidden++;
      failures.add('HIDDEN [$lang] $native');
      continue;
    }
    withGloss++;
    if (actual.join(' ') == expected.join(' ')) {
      exact++;
    } else {
      failures.add(
        '[$lang] expected: ${expected.join(' ')}\n'
        '       actual:   ${actual.join(' ')}',
      );
    }
  }

  return _AuditReport(
    name: 'ISL Conversational (HI/TA/ML × 100)',
    system: 'ISL',
    total: total,
    withGloss: withGloss,
    hidden: hidden,
    exactMatch: exact,
    failures: failures,
  );
}

_AuditReport _auditIslGrammarExamples() {
  final examples = <String, List<String>>{
    'I went to school yesterday': ['YESTERDAY', 'ME', 'SCHOOL', 'GO'],
    'I eat an apple': ['ME', 'APPLE', 'EAT'],
    'That book, I like it': ['BOOK', 'THAT', 'ME', 'LIKE'],
    'Where are you going?': ['YOU', 'GO', 'WHERE?'],
    'Are you coming?': ['[y/n-q]', 'YOU', 'COME?'],
    "I don't know": ['ME', 'KNOW', 'NOT'],
    'The boy is happy': ['BOY', 'HAPPY'],
    'I am tired': ['ME', 'TIRED'],
    'Big house': ['HOUSE', 'BIG'],
    'He is happy': ['POINT-THERE', 'HAPPY'],
    'Book on table': ['TABLE', 'BOOK-ON'],
    'I give you water': ['ME', 'GIVE-YOU'],
    'I stayed home because it rained': ['RAIN', 'HOME', 'ME', 'STAY'],
    'If rain comes, game cancelled': ['IF', 'RAIN', 'GAME', 'CANCEL'],
    'Today I go to work': ['TODAY', 'ME', 'WORK', 'GO'],
    '3 days': ['3-DAY'],
    'I am 25 years old': ['ME', 'AGE', '25'],
    'I am going home': ['ME', 'HOME', 'GO'],
  };

  var withGloss = 0;
  var hidden = 0;
  var exact = 0;
  final failures = <String>[];

  for (final entry in examples.entries) {
    final actual =
        SignGlossMapper.signSequence(entry.key, 'HI').map((t) => t.gloss).toList();
    if (actual.isEmpty) {
      hidden++;
      failures.add('HIDDEN: ${entry.key}');
      continue;
    }
    withGloss++;
    if (actual.join(' ') == entry.value.join(' ')) {
      exact++;
    } else {
      failures.add(
        '${entry.key}\n'
        '  expected: ${entry.value.join(' ')}\n'
        '  actual:   ${actual.join(' ')}',
      );
    }
  }

  return _AuditReport(
    name: 'ISL Grammar Examples (English → ISL rules)',
    system: 'ISL',
    total: examples.length,
    withGloss: withGloss,
    hidden: hidden,
    exactMatch: exact,
    failures: failures,
  );
}

_AuditReport _auditAslCategoryCorpus() {
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

  var withGloss = 0;
  var hidden = 0;
  var exact = 0;
  var overlapSum = 0.0;
  var fingerspell3 = 0;
  final failures = <String>[];

  for (var i = 0; i < sentences.length; i++) {
    final id = 'C${i + 1}';
    final sentence = sentences[i];
    final expected = expectedById[id]!;
    final actual =
        SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();

    if (actual.isEmpty) {
      hidden++;
      failures.add('HIDDEN $id: $sentence');
      continue;
    }
    withGloss++;
    final overlap = _tokenOverlap(expected, actual);
    overlapSum += overlap;
    final letters = actual.where((g) => g.length == 1).length;
    if (letters >= 3) {
      fingerspell3++;
    }
    if (_glossListsMatch(expected, actual)) {
      exact++;
    } else if (overlap < 0.5) {
      failures.add(
        '$id (${(overlap * 100).toStringAsFixed(0)}% overlap)\n'
        '  EN: $sentence\n'
        '  expected: ${expected.join(' ')}\n'
        '  actual:   ${actual.join(' ')}',
      );
    }
  }

  return _AuditReport(
    name: 'ASL Category Corpus (daily-life English)',
    system: 'ASL',
    total: sentences.length,
    withGloss: withGloss,
    hidden: hidden,
    exactMatch: exact,
    avgOverlap: overlapSum / sentences.length,
    fingerspell3Plus: fingerspell3,
    failures: failures,
  );
}

_AuditReport _auditAslGrammarShift() {
  final sentences = File('test/fixtures/asl_grammar_shift_sentences.txt')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();

  var withGloss = 0;
  var hidden = 0;
  var fingerspell3 = 0;
  final failures = <String>[];

  for (final sentence in sentences) {
    final actual =
        SignGlossMapper.signSequence(sentence, 'ENG').map((t) => t.gloss).toList();
    if (actual.isEmpty) {
      hidden++;
      failures.add('HIDDEN: $sentence');
      continue;
    }
    withGloss++;
    final letters = actual.where((g) => g.length == 1).length;
    if (letters >= 3) {
      fingerspell3++;
    }
  }

  return _AuditReport(
    name: 'ASL Grammar Shift (complex spoken English)',
    system: 'ASL',
    total: sentences.length,
    withGloss: withGloss,
    hidden: hidden,
    fingerspell3Plus: fingerspell3,
    failures: failures,
  );
}

_AuditReport _auditAslSpecExamples() {
  final examples = <String, List<String>>{
    'I went to the store yesterday': [
      'YESTERDAY',
      'STORE',
      'ME',
      'GO',
    ],
    'I like dogs': ['DOG', 'ME', 'LIKE'],
    'If it rains, the game is cancelled': ['IF', 'RAIN', 'GAME', 'CANCEL'],
    'Why did you go?': ['YOU', 'GO', 'WHY', '[wh-q]'],
    'Are you Deaf?': ['[y/n-q]', 'YOU', 'DEAF', 'YOU'],
    'The boy is happy': ['BOY', 'HAPPY'],
    'Big house': ['HOUSE', 'BIG'],
    'Book on table': ['TABLE', 'BOOK-ON'],
    'I give you water': ['ME', 'GIVE-YOU'],
    '3 days': ['3-DAY'],
    'I am 25 years old': ['ME', 'AGE', '25'],
    'Where are you going?': ['YOU', 'GO', 'WHERE', '[wh-q]'],
    "I don't know": ['ME', 'KNOW', 'NOT', '[headshake]'],
  };

  var withGloss = 0;
  var hidden = 0;
  var exact = 0;
  final failures = <String>[];

  for (final entry in examples.entries) {
    final actual =
        SignGlossMapper.signSequence(entry.key, 'ENG').map((t) => t.gloss).toList();
    if (actual.isEmpty) {
      hidden++;
      failures.add('HIDDEN: ${entry.key}');
      continue;
    }
    withGloss++;
    if (actual.join(' ') == entry.value.join(' ')) {
      exact++;
    } else {
      failures.add(
        '${entry.key}\n'
        '  expected: ${entry.value.join(' ')}\n'
        '  actual:   ${actual.join(' ')}',
      );
    }
  }

  return _AuditReport(
    name: 'ASL Spec Examples (Module 1–6 rules)',
    system: 'ASL',
    total: examples.length,
    withGloss: withGloss,
    hidden: hidden,
    exactMatch: exact,
    failures: failures,
  );
}

double _tokenOverlap(List<String> expected, List<String> actual) {
  if (expected.isEmpty) {
    return actual.isEmpty ? 1.0 : 0.0;
  }
  var matches = 0;
  for (final token in expected) {
    if (actual.contains(token)) {
      matches++;
    }
  }
  return matches / expected.length;
}

bool _glossListsMatch(List<String> expected, List<String> actual) {
  if (expected.length != actual.length) {
    return false;
  }
  for (var i = 0; i < expected.length; i++) {
    if (expected[i] != actual[i]) {
      return false;
    }
  }
  return true;
}

String _pct(int part, int total) {
  if (total == 0) {
    return '0';
  }
  return (part / total * 100).toStringAsFixed(1);
}
