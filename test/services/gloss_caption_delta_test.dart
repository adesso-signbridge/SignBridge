import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/gloss/gloss_caption_delta.dart';

void main() {
  group('GlossCaptionDelta.compute', () {
    test('returns full caption when nothing glossed yet', () {
      expect(
        GlossCaptionDelta.compute(
          fullCaption: 'hello how',
          glossedPrefix: '',
        ),
        'hello how',
      );
    });

    test('returns null when caption unchanged', () {
      expect(
        GlossCaptionDelta.compute(
          fullCaption: 'hello how',
          glossedPrefix: 'hello how',
        ),
        isNull,
      );
    });

    test('returns suffix after string prefix match', () {
      expect(
        GlossCaptionDelta.compute(
          fullCaption: 'hello how are you',
          glossedPrefix: 'hello how',
        ),
        'are you',
      );
    });

    test('returns null when only whitespace grows', () {
      expect(
        GlossCaptionDelta.compute(
          fullCaption: 'hello how  ',
          glossedPrefix: 'hello how',
        ),
        isNull,
      );
    });

    test('uses word-LCP fallback when string prefix diverges', () {
      expect(
        GlossCaptionDelta.compute(
          fullCaption: 'hello twelve are',
          glossedPrefix: 'hello one',
        ),
        'twelve are',
      );
    });

    test('returns null when full caption is shorter on word-LCP path', () {
      expect(
        GlossCaptionDelta.compute(
          fullCaption: 'hello',
          glossedPrefix: 'hello how',
        ),
        isNull,
      );
    });
  });
}
