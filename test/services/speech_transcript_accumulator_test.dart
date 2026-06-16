import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/services/translate/speech_transcript_accumulator.dart';

SpeechTranscriptAccumulator _iosTranscript() {
  return SpeechTranscriptAccumulator(iosRollingRefinement: true);
}

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

  test('session caption sync trusts accumulator live text', () {
    final transcript = _iosTranscript();
    var session = '';

    void syncSession(String incoming) {
      final next = incoming.trim();
      if (next.isEmpty) {
        return;
      }
      final prev = session.trim();
      if (prev.isNotEmpty && prev.startsWith(next)) {
        return;
      }
      session = next;
    }

    for (final part in [
      'Hello one',
      'Hello 12',
      'Hello 123 Mike test',
      'Hello 123 Mike testing am I audible yes you are audible',
    ]) {
      transcript.applyFinal(part);
      syncSession(transcript.live);
    }

    expect(session, 'Hello 123 Mike testing am I audible yes you are audible');
    expect(session.contains('Hello one Hello 12'), isFalse);
  });

  test('ios progressive finals collapse to latest refinement', () {
    final transcript = _iosTranscript();
    for (final part in ['Hello one', 'Hello 12', 'Hello 123 Mike test']) {
      transcript.applyFinal(part);
    }

    expect(transcript.live, 'Hello 123 Mike test');
  });

  test('ios progressive partials refine last commit not duplicate live', () {
    final transcript = _iosTranscript();
    transcript.applyFinal('Hello one');
    transcript.applyPartial('Hello 12');
    transcript.applyPartial('Hello 123 Mike test');

    expect(transcript.live, 'Hello 123 Mike test');
  });

  test('new sentence after pause still appends', () {
    final transcript = SpeechTranscriptAccumulator();
    transcript.applyFinal('Hello world');
    transcript.onRecognizerReset();
    transcript.applyFinal('Second sentence');

    expect(transcript.live, 'Hello world Second sentence');
  });

  test('ios replay partial does not repeat committed phrase', () {
    final transcript = _iosTranscript();
    transcript.applyFinal('hello world');
    transcript.onRecognizerReset();
    transcript.applyPartial('hello world hello world how are you');

    expect(transcript.live, 'hello world how are you');
  });

  test('mergeSessionCaption strips ios replay in suffix', () {
    expect(
      SpeechTranscriptAccumulator.mergeSessionCaption(
        'hello world',
        'hello world hello world how are you',
      ),
      'hello world how are you',
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
