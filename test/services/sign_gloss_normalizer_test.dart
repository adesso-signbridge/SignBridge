import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/avatar/sign_gloss_normalizer.dart';

void main() {
  group('SignGlossNormalizer', () {
    test('normalizeKey handles underscores and hyphens', () {
      expect(SignGlossNormalizer.normalizeKey('THANK-YOU'), 'thank_you');
      expect(SignGlossNormalizer.normalizeKey('wake_up'), 'wake_up');
    });
  });
}
