import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/avatar/cwasa_sigml_catalog.dart';

void main() {
  group('CwasaSigmlCatalog', () {
    test('buildDocument returns null for thinking placeholder', () {
      expect(CwasaSigmlCatalog.buildDocument('...'), isNull);
    });

    test('buildDocument combines known gloss tokens', () {
      final doc = CwasaSigmlCatalog.buildDocument('ME WANT MUG');
      expect(doc, isNotNull);
      expect(doc, contains('<hamgestural_sign gloss="i">'));
      expect(doc, contains('<hamgestural_sign gloss="take">'));
      expect(doc, contains('<hamgestural_sign gloss="mug">'));
    });

    test('remoteUrlForPhrase maps demo phrase', () {
      expect(
        CwasaSigmlCatalog.remoteUrlForPhrase('I WANT MUG'),
        CwasaSigmlCatalog.iTakeMugUrl,
      );
    });

    test('fragmentForToken normalizes underscores', () {
      expect(
        CwasaSigmlCatalog.fragmentForToken('pass_me'),
        isNotNull,
      );
    });

    test('signDocumentsForPhrase returns one document per mapped token', () {
      final docs = CwasaSigmlCatalog.signDocumentsForPhrase('HELLO YOU HOW');
      expect(docs.length, 3);
    });

    test('glossTokenDelta returns appended tokens only', () {
      expect(
        CwasaSigmlCatalog.glossTokenDelta('HELLO YOU', 'HELLO YOU HOW ME'),
        'HOW ME',
      );
    });

    test('buildDocumentForDelta builds only new signs', () {
      final doc = CwasaSigmlCatalog.buildDocumentForDelta(
        previousPhrase: 'HELLO YOU',
        currentPhrase: 'HELLO YOU HOW ME',
      );
      expect(doc, isNotNull);
      expect(doc, contains('<hamgestural_sign gloss="take">'));
      expect(doc, contains('<hamgestural_sign gloss="i">'));
      expect(doc!.split('<hamgestural_sign').length - 1, 2);
    });

    test('buildDocument maps greeting gloss tokens', () {
      final doc = CwasaSigmlCatalog.buildDocument('HELLO YOU HOW');
      expect(doc, isNotNull);
      expect(doc, contains('<hamgestural_sign gloss="take">'));
      expect(doc, contains('<hamgestural_sign gloss="i">'));
    });

    test('buildDocument skips unknown tokens', () {
      final doc = CwasaSigmlCatalog.buildDocument('XYZZY QWERTY');
      expect(doc, isNull);
    });
  });
}
