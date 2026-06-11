import 'package:flutter_test/flutter_test.dart';
import 'package:sign_bridge/app/sign_bridge_app.dart';
import 'package:sign_bridge/core/di/service_locator.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/adesso_logo.dart';
import 'package:sign_bridge/features/splash/presentation/widgets/sign_bridge_logo.dart';
import 'package:sign_bridge/shell/main_shell.dart';

void main() {
  setUp(ServiceLocator.bootstrap);

  testWidgets('Splash screen shows SignBridge branding', (WidgetTester tester) async {
    await tester.pumpWidget(const SignBridgeApp());

    expect(find.text('SignBridge'), findsOneWidget);
    expect(find.byType(AdessoLogo), findsOneWidget);
    expect(find.byType(SignBridgeLogo), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('Home screen shows main sections', (WidgetTester tester) async {
    await tester.pumpWidget(const SignBridgeApp());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Hear for me'), findsOneWidget);
    expect(find.text('Speak for me'), findsOneWidget);
    expect(find.text('Quick Phrases'), findsOneWidget);
    expect(find.text('Hello, nice to meet you.'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });
}
