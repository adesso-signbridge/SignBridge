import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/features/home/presentation/widgets/sign_camera_recorder.dart';
import 'package:sign_bridge/services/home/home_ui_copy.dart';
import 'package:sign_bridge/services/translate/sign_capture_config.dart';

void main() {
  group('SignCaptureConfig', () {
    test('manual stop flow allows up to 30 second clips', () {
      expect(SignCaptureConfig.maxRecordingDuration.inSeconds, 30);
      expect(SignCaptureConfig.minRecordingDuration.inSeconds, 2);
      expect(SignCaptureConfig.workerRequestTimeout.inSeconds, 240);
    });
  });

  group('HomeUiCopy sign recording', () {
    test('ENG includes tap to record label', () {
      final copy = homeUiCopyFor('ENG');
      expect(copy.tapToRecordSign, isNotEmpty);
      expect(copy.recordingSignsLabel.toLowerCase(), contains('stop'));
    });
  });

  group('TalkSignCameraActionBar', () {
    testWidgets('flip is disabled while recording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TalkSignCameraActionBar(
              flipSemanticsLabel: 'Flip camera',
              canFlip: false,
              flipBusy: false,
              onFlip: () {},
            ),
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('talk_sign_flip_camera_button')),
      );
      expect(inkWell.onTap, isNull);
    });

    testWidgets('flip is enabled in preview', (tester) async {
      var flipped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TalkSignCameraActionBar(
              flipSemanticsLabel: 'Flip camera',
              canFlip: true,
              flipBusy: false,
              onFlip: () => flipped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('talk_sign_flip_camera_button')));
      expect(flipped, isTrue);
    });
  });
}
