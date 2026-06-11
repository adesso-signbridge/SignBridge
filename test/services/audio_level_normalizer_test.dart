import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/audio_level_normalizer.dart';

void main() {
  test('maps silence and negative dB to zero', () {
    expect(AudioLevelNormalizer.toVisualLevel(-50), 0);
    expect(AudioLevelNormalizer.toVisualLevel(-2), 0);
    expect(AudioLevelNormalizer.toVisualLevel(0), 0);
  });

  test('maps Android-style positive dB to visual level', () {
    expect(AudioLevelNormalizer.toVisualLevel(0), 0);
    expect(AudioLevelNormalizer.toVisualLevel(6), closeTo(0.5, 0.01));
    expect(AudioLevelNormalizer.toVisualLevel(12), 1);
  });

  test('center bars weigh higher than edge bars', () {
    const count = 16;
    final center = AudioLevelNormalizer.barWeight(7, count);
    final edge = AudioLevelNormalizer.barWeight(0, count);
    expect(center, greaterThan(edge));
  });
}
