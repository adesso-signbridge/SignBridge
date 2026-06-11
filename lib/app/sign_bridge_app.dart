import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../shell/main_shell.dart';

class SignBridgeApp extends StatefulWidget {
  const SignBridgeApp({super.key});

  @override
  State<SignBridgeApp> createState() => _SignBridgeAppState();
}

class _SignBridgeAppState extends State<SignBridgeApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final splashService = ServiceLocator.instance.splash;

    return MaterialApp(
      title: 'SignBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006EC7)),
        useMaterial3: true,
      ),
      home: _showSplash
          ? SplashScreen(
              splashService: splashService,
              onFinished: () => setState(() => _showSplash = false),
            )
          : const MainShell(),
    );
  }
}
