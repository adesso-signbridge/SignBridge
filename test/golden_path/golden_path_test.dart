import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/speech_transcript_accumulator.dart';

/// Automated golden-path checks for Tap to Listen → caption → stop.
@Tags(['golden-path'])
void main() {
  group('golden path: listen session caption', () {
    test('caption grows across STT chunks until stop', () {
      var caption = '';
      caption = SpeechTranscriptAccumulator.mergeSessionCaption(
        caption,
        'Hello, how are',
      );
      caption = SpeechTranscriptAccumulator.mergeSessionCaption(
        caption,
        'Hello, how are you today?',
      );

      expect(caption, 'Hello, how are you today?');
    });

    test('pause between phrases keeps prior words', () {
      final transcript = SpeechTranscriptAccumulator();
      transcript.applyFinal('Good morning.');
      transcript.onRecognizerReset();
      transcript.applyPartial('Thanks for joining.');

      expect(transcript.live, 'Good morning. Thanks for joining.');
    });
  });
}
