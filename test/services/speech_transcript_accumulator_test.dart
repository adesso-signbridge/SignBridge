import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/speech_transcript_accumulator.dart';

void main() {
  test('partial refinements grow one utterance', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyPartial('Hello');
    transcript.applyPartial('Hello how');
    transcript.applyPartial('Hello how are you');

    expect(transcript.live, 'Hello how are you');
  });

  test('partial then final appends without duplication', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyPartial('Hello');
    transcript.applyPartial('Hello how');
    transcript.applyFinal('Hello how are you');

    expect(transcript.live, 'Hello how are you');
    expect(transcript.committed, 'Hello how are you');
  });

  test('cumulative partial includes committed prefix', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Hello there.');
    transcript.applyPartial('Hello there. How are');

    expect(transcript.live, 'Hello there. How are');
  });

  test('cumulative final replaces committed text', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Hello');
    transcript.applyFinal('Hello how are you');

    expect(transcript.committed, 'Hello how are you');
    expect(transcript.live, 'Hello how are you');
  });

  test('new phrase after final appends to committed', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('First sentence.');
    transcript.applyPartial('Second sentence');

    expect(transcript.live, 'First sentence. Second sentence');
  });

  test('duplicate trailing partial does not shrink live text', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Hello world');
    transcript.applyPartial('world');

    expect(transcript.live, 'Hello world');
  });

  test('regressive partial does not shrink live text', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyPartial('Hello how are you');
    transcript.applyPartial('Hello how');

    expect(transcript.live, 'Hello how are you');
  });

  test('recognizer reset keeps committed text and avoids duplicates', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('First sentence.');
    transcript.applyPartial('First sentence. Second');
    transcript.onRecognizerReset();
    transcript.applyPartial('Second sentence');

    expect(transcript.live, 'First sentence. Second sentence');
    expect(transcript.committed, 'First sentence. Second');
  });

  test('finalizeOpenDraft commits in-progress speech on pause', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyPartial('Hello how are');
    transcript.finalizeOpenDraft();

    expect(transcript.committed, 'Hello how are');
    expect(transcript.live, 'Hello how are');
  });

  test('regressive partial after committed text is ignored', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Hello how are you');
    transcript.applyPartial('Hello how');

    expect(transcript.live, 'Hello how are you');
  });

  test('repeated short words append across a long conversation', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Good morning. I have a meeting at nine.');
    transcript.applyFinal('Yes, that works for me.');
    transcript.applyFinal('Yes');

    expect(
      transcript.committed,
      'Good morning. I have a meeting at nine. Yes, that works for me. Yes',
    );
  });

  test('many pause segments grow one continuous transcript', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('First topic done.');
    transcript.onRecognizerReset();
    transcript.applyPartial('Second topic starts');
    transcript.finalizeOpenDraft();
    transcript.onRecognizerReset();
    transcript.applyFinal('Third topic closes.');

    expect(
      transcript.live,
      'First topic done. Second topic starts Third topic closes.',
    );
  });

  test('third utterance partials grow after two committed segments', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Good morning everyone.');
    transcript.onRecognizerReset();
    transcript.applyFinal('Thanks for joining today.');
    transcript.onRecognizerReset();
    transcript.applyPartial('Let');
    transcript.applyPartial('Let us begin');

    expect(
      transcript.live,
      'Good morning everyone. Thanks for joining today. Let us begin',
    );
  });

  test('mergeSessionCaption grows across unrelated STT chunks', () {
    var caption = '';
    caption = SpeechTranscriptAccumulator.mergeSessionCaption(
      caption,
      'Good morning everyone.',
    );
    caption = SpeechTranscriptAccumulator.mergeSessionCaption(
      caption,
      'Thanks for joining today.',
    );
    caption = SpeechTranscriptAccumulator.mergeSessionCaption(
      caption,
      'Let us begin.',
    );

    expect(
      caption,
      'Good morning everyone. Thanks for joining today. Let us begin.',
    );
  });

  test('mergeSessionCaption never shortens on regressive STT text', () {
    const previous = 'Hello how are you today';
    expect(
      SpeechTranscriptAccumulator.mergeSessionCaption(previous, 'Hello how'),
      previous,
    );
  });

  test('mergeSessionCaption joins overlapping chunk boundaries once', () {
    expect(
      SpeechTranscriptAccumulator.mergeSessionCaption(
        'I need help',
        'help now please',
      ),
      'I need help now please',
    );
  });

  test('segment-only partial after long committed text is not rejected', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('One.');
    transcript.onRecognizerReset();
    transcript.applyFinal('Two.');
    transcript.onRecognizerReset();
    transcript.applyPartial('Three');

    expect(transcript.live, 'One. Two. Three');
    expect(transcript.live.length, greaterThan(transcript.committed.length));
  });
}
