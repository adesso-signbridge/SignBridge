import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/features/home/presentation/widgets/talk_audio_waveform.dart';

void main() {
  double barHeight(WidgetTester tester, int index) {
    return tester.getSize(find.byKey(Key('talk_waveform_bar_$index'))).height;
  }

  testWidgets('live mode bar heights track rising input level', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TalkAudioWaveform(level: 0.05, live: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final lowTrailing = barHeight(tester, 15);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TalkAudioWaveform(level: 0.95, live: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final highTrailing = barHeight(tester, 15);
    expect(highTrailing, greaterThan(lowTrailing + 4));
  });

  testWidgets('decaying mode lowers bars toward idle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TalkAudioWaveform(level: 0.9, live: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final peakTrailing = barHeight(tester, 15);
    expect(peakTrailing, greaterThan(8));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TalkAudioWaveform(level: 0.9, live: false, decaying: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final decayedTrailing = barHeight(tester, 15);
    expect(decayedTrailing, lessThan(peakTrailing * 0.6));
  });
}
