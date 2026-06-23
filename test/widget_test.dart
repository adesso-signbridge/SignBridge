import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/app/sign_bridge_app.dart';
import 'package:sign_bridge/core/di/service_locator.dart';
import 'package:sign_bridge/core/platform/microphone_permission.dart';
import 'package:sign_bridge/core/platform/sign_camera_test_mode.dart';
import 'package:sign_bridge/core/platform/speech_permission.dart';
import 'package:sign_bridge/services/translate/local_translate_service.dart';

import 'services/mock_phrase_speech_service.dart';
import 'services/mock_sign_capture_service.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/adesso_logo.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/sign_bridge_logo.dart';
import 'package:sign_bridge/shell/main_shell.dart';

void main() {
  final mockPhraseSpeech = MockPhraseSpeechService();
  final mockSignCapture = MockSignCaptureService();

  setUp(() {
    signCameraTestModeEnabled = true;
    ServiceLocator.bootstrap(
      translate: LocalTranslateService(forceMockListening: true),
      signCapture: mockSignCapture,
      phraseSpeech: mockPhraseSpeech,
    );
    microphonePermissionRequester = () async => true;
    speechPermissionRequester = () async => true;
    mockPhraseSpeech.lastSpokenText = null;
    mockSignCapture.lastVideoPath = null;
  });

  tearDown(() async {
    signCameraTestModeEnabled = false;
    await ServiceLocator.instance.translate.cancelListening();
  });

  testWidgets('Splash screen shows SignBridge branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    expect(find.text('SignBridge'), findsOneWidget);
    expect(find.byType(AdessoLogo), findsOneWidget);
    expect(find.byType(SignBridgeLogo), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('Talk screen shows main sections', (WidgetTester tester) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.textContaining('No conversation yet'), findsOneWidget);
    expect(find.text('Tap to listen'), findsOneWidget);
    expect(find.text('Tap to sign'), findsOneWidget);
    expect(find.text('Talk'), findsOneWidget);
    expect(find.text('Phrases'), findsOneWidget);
  });

  testWidgets('Hamburger menu opens settings with SOS and version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_menu_button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('Tap sign records, analyzes, speaks, and shows spoken bubble', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('talk_sign_button')));
    await tester.pump();

    expect(find.textContaining('Recording signs'), findsOneWidget);
    expect(find.byKey(const Key('talk_sign_flip_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('talk_sign_send_button')), findsOneWidget);
    expect(find.text('Tap to translate'), findsNothing);
    expect(find.text('Clear history'), findsNothing);

    await tester.tap(find.byKey(const Key('talk_sign_send_button')));
    await tester.pump();

    expect(find.text('Analyzing your signs…'), findsOneWidget);
    expect(find.text('Clear history'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('talk_sign_spoken_content')), findsOneWidget);
    expect(find.text('Clear history'), findsOneWidget);
    expect(find.textContaining('My name is Alex. I am deaf.'), findsOneWidget);
    expect(find.textContaining('Spoken · 01:00'), findsOneWidget);
    expect(find.byKey(const Key('talk_sign_clear_button')), findsOneWidget);
    expect(mockSignCapture.lastVideoPath, 'mock-sign-capture.mp4');
    expect(mockPhraseSpeech.lastSpokenText, 'My name is Alex. I am deaf.');

    await tester.tap(find.byKey(const Key('talk_sign_clear_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('talk_sign_spoken_content')), findsNothing);
    expect(find.textContaining('My name is Alex. I am deaf.'), findsNothing);
    expect(find.byKey(const Key('talk_sign_recording_content')), findsOneWidget);
    expect(find.textContaining('Recording signs'), findsOneWidget);
    expect(find.byKey(const Key('talk_sign_flip_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('talk_sign_send_button')), findsOneWidget);
  });

  testWidgets('Phrases tab shows categories and speaks on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Phrases'));
    await tester.pumpAndSettle();

    expect(find.text('Search phrases…'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Greetings'), findsWidgets);
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.text('Hello'));
    await tester.pump();

    expect(mockPhraseSpeech.lastSpokenText, 'Hello');
    expect(mockPhraseSpeech.lastLanguageCode, 'ENG');
  });

  testWidgets('Changing language updates talk screen copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('മലയാളം'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('കേൾക്കാൻ ടാപ്പ് ചെയ്യുക'), findsOneWidget);
    expect(find.text('സംസാരം'), findsOneWidget);
    expect(find.textContaining('ലേക്ക് മാറ്റി'), findsOneWidget);
  });

  testWidgets('Changing language while listening asks for confirmation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('talk_listen_button')));
    await tester.pump();
    expect(find.text('Listening...'), findsOneWidget);

    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('മലയാളം'));
    await tester.pumpAndSettle();

    expect(find.text('Change language?'), findsOneWidget);
    expect(
      find.text('This will stop listening and clear the current caption.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Change'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Listening...'), findsNothing);
    expect(find.textContaining('ലേക്ക് മാറ്റി'), findsOneWidget);
    expect(find.text('കേൾക്കാൻ ടാപ്പ് ചെയ്യുക'), findsOneWidget);
  });

  testWidgets('Clear history hides during sign flow after listen stops', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('talk_listen_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('talk_stop_button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Clear history'), findsOneWidget);

    await tester.tap(find.byKey(const Key('talk_sign_button')));
    await tester.pump();

    expect(find.text('Clear history'), findsNothing);
  });

  testWidgets('Tap send locks caption, shows gloss, then clear resumes listen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('talk_listen_button')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));

    expect(find.textContaining('Hello, how are'), findsOneWidget);
    expect(find.byKey(const Key('talk_caption_send_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('talk_caption_send_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('talk_caption_clear_button')), findsOneWidget);
    expect(find.byKey(const Key('talk_caption_send_button')), findsNothing);
    expect(find.byKey(const Key('talk_audio_waveform')), findsNothing);
    expect(find.textContaining('Signing:'), findsOneWidget);
    expect(find.textContaining('Hello, how are'), findsOneWidget);

    await tester.tap(find.byKey(const Key('talk_caption_clear_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('talk_caption_clear_button')), findsNothing);
    expect(find.text('Listening...'), findsOneWidget);
    expect(find.byKey(const Key('talk_audio_waveform')), findsOneWidget);
  });

  testWidgets('Tap listen then stop shows stopped state with transcript', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('talk_listen_button')));
    await tester.pump();

    expect(find.text('Listening...'), findsOneWidget);
    expect(find.text('Tap to stop'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));

    expect(find.textContaining('Hello, how are'), findsOneWidget);

    await tester.tap(find.byKey(const Key('talk_stop_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('talk_stopped_content')), findsOneWidget);
    expect(find.textContaining('Hello, how are'), findsOneWidget);
    expect(find.byKey(const Key('talk_audio_waveform')), findsNothing);

    await tester.tap(find.byKey(const Key('talk_clear_history_button')));
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
    'Tap stop shows stopped state and clear history returns to idle',
    (WidgetTester tester) async {
      await tester.pumpWidget(const SignBridgeApp());

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('talk_listen_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Listening...'), findsOneWidget);

      await tester.tap(find.byKey(const Key('talk_stop_button')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('talk_stopped_content')), findsOneWidget);
      expect(find.text('Clear history'), findsOneWidget);
      expect(find.text('No speech detected.'), findsOneWidget);
      expect(find.textContaining('Hello, how are you today?'), findsNothing);
      expect(find.text('Tap to listen'), findsOneWidget);
      expect(find.byKey(const Key('talk_stop_button')), findsNothing);

      await tester.tap(find.byKey(const Key('talk_clear_history_button')));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No conversation yet'), findsOneWidget);
      expect(find.text('Clear history'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2300));
    },
  );
}
