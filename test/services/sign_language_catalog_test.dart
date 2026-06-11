import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/sign_gloss_mapper.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';

void main() {
  test('English maps to ASL gloss sequence', () {
    final sequence = SignGlossMapper.signSequence(
      'Hello, how are you today?',
      'ENG',
    );
    expect(sequence.map((t) => t.gloss).toList(), [
      'HELLO',
      'HOW',
      'YOU',
      'TODAY',
    ]);
    expect(sequence.first.system, SignLanguageSystem.asl);
  });

  test('Hindi maps to ISL gloss sequence', () {
    final sequence = SignGlossMapper.signSequence('नमस्ते, कैसे हैं', 'HI');
    expect(sequence.first.system, SignLanguageSystem.isl);
    expect(sequence.first.gloss, 'HELLO');
    expect(sequence.map((t) => t.gloss), contains('HOW'));
  });
}
