import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/app/sign_bridge_app.dart';
import 'package:sign_bridge/core/di/service_locator.dart';
import 'package:sign_bridge/core/platform/microphone_permission.dart';
import 'package:sign_bridge/services/translate/local_translate_service.dart';

import 'services/mock_phrase_speech_service.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/adesso_logo.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/sign_bridge_logo.dart';
import 'package:sign_bridge/shell/main_shell.dart';

void main() {
  final mockPhraseSpeech = MockPhraseSpeechService();

  setUp(() {
    ServiceLocator.bootstrap(
      translate: LocalTranslateService(forceMockListening: true),
      phraseSpeech: mockPhraseSpeech,
    );
    microphonePermissionRequester = () async => true;
    mockPhraseSpeech.lastSpokenText = null;
  });

  tearDown(() async {
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
    await tester.pumpAndSettle();

    expect(find.text('കേൾക്കാൻ ടാപ്പ് ചെയ്യുക'), findsOneWidget);
    expect(find.text('സംസാരം'), findsOneWidget);
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
