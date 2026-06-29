import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/avatar/isl_video_gloss_aliases.dart';
import 'package:sign_bridge/services/avatar/sign_asset_catalog.dart';
import 'package:sign_bridge/services/translate/asl_sign_lexicon.dart';
import 'package:sign_bridge/services/translate/english_lexicon.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EnglishLexicon.load();
    await AslSignLexicon.load();
    await SignAssetCatalog.ensureLoaded();
  });

  test('ISL conversational glosses resolve to bundled videos', () {
    final fixture = File('test/fixtures/isl_conversational_sets.txt');
    final lines = fixture.readAsLinesSync();
    var totalTokens = 0;
    var resolvedTokens = 0;
    final missing = <String, int>{};

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) {
        continue;
      }
      final parts = line.split('|');
      if (parts.length < 3) {
        continue;
      }
      final lang = parts[0];
      final native = parts[1];
      final sequence = SignGlossMapper.signSequence(native, lang);
      for (final token in sequence) {
        if (token.gloss.startsWith('[') || token.gloss.startsWith('FS-')) {
          continue;
        }
        totalTokens++;
        final path = SignAssetCatalog.assetPathForToken(
          token,
          SignLanguageSystem.isl,
        );
        if (path != null) {
          resolvedTokens++;
        } else {
          final key = token.gloss.replaceAll(RegExp(r'[?!]+$'), '');
          missing.update(key, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }

    final coverage = resolvedTokens / totalTokens;
    // ignore: avoid_print
    print(
      'ISL video coverage: $resolvedTokens/$totalTokens '
      '(${ (coverage * 100).toStringAsFixed(1)}%)',
    );
    if (missing.isNotEmpty) {
      final top = missing.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in top.take(15)) {
        final alias = IslVideoGlossAliases.manifestKeyFor(entry.key);
        // ignore: avoid_print
        print('  missing ${entry.key} (${entry.value}x) alias=$alias');
      }
    }

    expect(
      coverage,
      greaterThan(0.85),
      reason: 'ISL gloss video coverage should exceed 85%',
    );
  });
}
