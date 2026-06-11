import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Repository hygiene checks commonly used in production Flutter CI pipelines.
void main() {
  group('pubspec integrity', () {
    late YamlMap pubspec;

    setUp(() {
      pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    });

    test('declared asset files exist on disk', () {
      final flutterConfig = pubspec['flutter'] as YamlMap?;
      final assets = flutterConfig?['assets'] as YamlList? ?? YamlList();

      for (final asset in assets) {
        final path = asset.toString();
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'Missing asset declared in pubspec.yaml: $path',
        );
      }
    });

    test('declared font files exist on disk', () {
      final flutterConfig = pubspec['flutter'] as YamlMap?;
      final fonts = flutterConfig?['fonts'] as YamlList? ?? YamlList();

      for (final fontEntry in fonts) {
        final fontMap = fontEntry as YamlMap;
        final fontFiles = fontMap['fonts'] as YamlList? ?? YamlList();

        for (final fontFile in fontFiles) {
          final assetPath = (fontFile as YamlMap)['asset']?.toString();
          expect(assetPath, isNotNull, reason: 'Font entry missing asset path');
          expect(
            File(assetPath!).existsSync(),
            isTrue,
            reason: 'Missing font declared in pubspec.yaml: $assetPath',
          );
        }
      }
    });

    test('project uses a pinned SDK constraint', () {
      final environment = pubspec['environment'] as YamlMap?;
      final sdk = environment?['sdk']?.toString();

      expect(sdk, isNotNull);
      expect(sdk, isNotEmpty);
    });
  });

  group('repository hygiene', () {
    test('forbidden local artifact directories are not tracked', () {
      const forbiddenPrefixes = ['.cursor/', '.venv_pdf/', '.venv/'];

      final trackedFiles = Process.runSync('git', [
        'ls-files',
      ]).stdout.toString().split('\n');

      for (final trackedFile in trackedFiles) {
        if (trackedFile.isEmpty) {
          continue;
        }

        for (final prefix in forbiddenPrefixes) {
          expect(
            trackedFile.startsWith(prefix),
            isFalse,
            reason: '$trackedFile must not be committed ($prefix)',
          );
        }
      }
    });

    test('forbidden secret files are absent', () {
      const forbiddenFiles = [
        '.env',
        '.env.local',
        'credentials.json',
        'google-services.json',
        'GoogleService-Info.plist',
      ];

      for (final file in forbiddenFiles) {
        expect(
          File(file).existsSync(),
          isFalse,
          reason: '$file must not be committed to the repository',
        );
      }
    });

    test('CI workflow defines PR merge gate for seven core checks', () {
      final ci = File('.github/workflows/ci.yml').readAsStringSync();
      expect(ci, contains('name: PR merge gate'));
      expect(ci, contains('-lt 7'));
      expect(ci, contains('Coding standards'));
      expect(ci, contains('iOS TestFlight build check'));
    });

    test('branch protection setup script exists', () {
      final script = File('scripts/setup-branch-protection.sh');
      expect(script.existsSync(), isTrue);
      expect(
        script.readAsStringSync(),
        contains('PR merge gate'),
      );
    });

    test('lib source avoids debug print statements', () {
      final violations = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index].trim();
          if (line.contains('print(') && !line.startsWith('//')) {
            violations.add('${file.path}:${index + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Use logging abstractions instead of print() in lib/:\n${violations.join('\n')}',
      );
    });
  });
}
