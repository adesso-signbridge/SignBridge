import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/features/home/presentation/widgets/talk_sign_session_content.dart';
import 'package:sign_bridge/services/home/home_ui_copy.dart';

void main() {
  testWidgets('analyzing status bubble wraps long Tamil label without overflow', (
    WidgetTester tester,
  ) async {
    final uiCopy = homeUiCopyFor('TA');

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: TalkSignAnalyzingStatusBubble(
                label: uiCopy.analyzingSignsLabel,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(uiCopy.analyzingSignsLabel), findsOneWidget);
  });

  testWidgets('recording status bubble wraps long Malayalam label without overflow', (
    WidgetTester tester,
  ) async {
    final uiCopy = homeUiCopyFor('ML');

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: TalkSignRecordingStatusBubble(
                label: uiCopy.recordingSignsLabel,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(uiCopy.recordingSignsLabel), findsOneWidget);
  });
}
