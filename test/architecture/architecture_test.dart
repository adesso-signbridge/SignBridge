import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardrails for SignBridge's feature-first, microservice-client layout.
void main() {
  const serviceDomains = [
    'splash',
    'home',
    'translate',
    'phrases',
    'sos',
    'settings',
  ];

  group('folder structure', () {
    test('required architecture directories exist', () {
      const requiredDirectories = [
        'lib/app',
        'lib/core/di',
        'lib/core/network',
        'lib/core/services',
        'lib/core/theme',
        'lib/features',
        'lib/services',
        'lib/shell',
      ];

      for (final directory in requiredDirectories) {
        expect(
          Directory(directory).existsSync(),
          isTrue,
          reason: 'Missing required directory: $directory',
        );
      }
    });
  });

  group('microservice modules', () {
    test('each domain has an interface and local adapter', () {
      for (final domain in serviceDomains) {
        final interfaceFile = File(
          'lib/services/$domain/${domain}_service.dart',
        );
        final localFile = File(
          'lib/services/$domain/local_${domain}_service.dart',
        );

        expect(
          interfaceFile.existsSync(),
          isTrue,
          reason: 'Missing $interfaceFile',
        );
        expect(localFile.existsSync(), isTrue, reason: 'Missing $localFile');
      }
    });

    test('service interfaces implement Microservice', () {
      for (final domain in serviceDomains) {
        final contents = File(
          'lib/services/$domain/${domain}_service.dart',
        ).readAsStringSync();
        expect(
          contents.contains('implements Microservice'),
          isTrue,
          reason: '${domain}_service.dart must implement Microservice',
        );
      }
    });

    test('ServiceLocator wires local adapters only', () {
      final contents = File(
        'lib/core/di/service_locator.dart',
      ).readAsStringSync();

      for (final domain in serviceDomains) {
        final className = 'Local${_pascalCase(domain)}Service';
        expect(
          contents.contains(className),
          isTrue,
          reason: 'ServiceLocator must register $className',
        );
      }

      expect(
        contents.contains('LocalHomeService()'),
        isTrue,
        reason: 'ServiceLocator.bootstrap must instantiate local adapters',
      );
    });
  });

  group('layer boundaries', () {
    test('features do not import concrete local service adapters', () {
      final violations = _collectImportViolations(
        root: 'lib/features',
        forbiddenPatterns: ['local_', '/local_'],
      );

      expect(
        violations,
        isEmpty,
        reason:
            'Presentation layer must depend on service interfaces only:\n${violations.join('\n')}',
      );
    });

    test('features do not import ServiceLocator directly', () {
      final violations = _collectImportViolations(
        root: 'lib/features',
        forbiddenPatterns: ['service_locator.dart'],
      );

      expect(
        violations,
        isEmpty,
        reason:
            'Features must receive dependencies via constructors, not ServiceLocator:\n${violations.join('\n')}',
      );
    });

    test('features do not import network client directly', () {
      final violations = _collectImportViolations(
        root: 'lib/features',
        forbiddenPatterns: ['microservice_client.dart'],
      );

      expect(
        violations,
        isEmpty,
        reason:
            'Presentation layer must not call HTTP client directly:\n${violations.join('\n')}',
      );
    });

    test('service interfaces do not import Flutter UI packages', () {
      final violations = <String>[];

      for (final domain in serviceDomains) {
        final file = File('lib/services/$domain/${domain}_service.dart');
        final lines = file.readAsLinesSync();

        for (final line in lines) {
          if (!line.trim().startsWith('import ')) {
            continue;
          }
          if (line.contains('package:flutter/')) {
            violations.add('${file.path}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Service contracts must stay UI-free:\n${violations.join('\n')}',
      );
    });
  });
}

List<String> _collectImportViolations({
  required String root,
  required List<String> forbiddenPatterns,
}) {
  final violations = <String>[];
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('import ')) {
        continue;
      }

      final matchesForbiddenPattern = forbiddenPatterns.any(trimmed.contains);
      if (matchesForbiddenPattern) {
        violations.add('${file.path}: $trimmed');
      }
    }
  }

  return violations;
}

String _pascalCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() + value.substring(1);
}
