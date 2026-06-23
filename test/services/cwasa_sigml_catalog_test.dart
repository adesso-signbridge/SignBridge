import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/avatar/cwasa_sigml_catalog.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';
import 'package:sign_bridge/services/translate/sign_token.dart';

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
        isNotEmpty,
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

    test('buildDocument maps every gloss token', () {
      final doc = CwasaSigmlCatalog.buildDocument('XYZZY QWERTY');
      expect(doc, isNotNull);
      expect(doc!.split('<hamgestural_sign').length - 1, 2);
    });

    test('buildDocument maps conversational gloss tokens', () {
      final doc = CwasaSigmlCatalog.buildDocument(
        'GOOD MORNING IS THIS GOOD TIME TO TALK',
      );
      expect(doc, isNotNull);
      expect(
        doc!.split('<hamgestural_sign').length - 1,
        8,
      );
    });

    test('buildDocumentFromSequence animates every token', () {
      final sequence = [
        const SignToken(id: 'good', gloss: 'GOOD', system: SignLanguageSystem.asl),
        const SignToken(id: 'morning', gloss: 'MORNING', system: SignLanguageSystem.asl),
        const SignToken(id: 'time', gloss: 'TIME', system: SignLanguageSystem.asl),
        const SignToken(id: 'talk', gloss: 'TALK', system: SignLanguageSystem.asl),
      ];
      final doc = CwasaSigmlCatalog.buildDocumentFromSequence(sequence);
      expect(doc, isNotNull);
      expect(doc!.split('<hamgestural_sign').length - 1, 4);
    });

    test('buildDocumentForSequenceDelta builds only appended tokens', () {
      final previous = [
        const SignToken(id: 'hello', gloss: 'HELLO', system: SignLanguageSystem.asl),
        const SignToken(id: 'you', gloss: 'YOU', system: SignLanguageSystem.asl),
      ];
      final current = [
        ...previous,
        const SignToken(id: 'how', gloss: 'HOW', system: SignLanguageSystem.asl),
        const SignToken(id: 'me', gloss: 'ME', system: SignLanguageSystem.asl),
      ];
      final doc = CwasaSigmlCatalog.buildDocumentForSequenceDelta(
        previous: previous,
        current: current,
      );
      expect(doc, isNotNull);
      expect(doc!.split('<hamgestural_sign').length - 1, 2);
    });
  });
}
