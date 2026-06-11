import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/app/sign_bridge_app.dart';
import 'package:sign_bridge/core/di/service_locator.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/adesso_logo.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/sign_bridge_logo.dart';
import 'package:sign_bridge/shell/main_shell.dart';

void main() {
  setUp(ServiceLocator.bootstrap);

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
}
