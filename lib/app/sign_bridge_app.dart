import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shell/main_shell.dart';

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006EC7)),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          return SplashScreen(
            splashService: ServiceLocator.instance.splash,
            onFinished: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const MainShell()),
              );
            },
          );
        },
      ),
    );
  }
}
