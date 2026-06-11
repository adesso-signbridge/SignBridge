import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/splash/splash_service.dart';
import 'widgets/adesso_logo.dart';
import 'widgets/sign_bridge_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.splashService,
    required this.onFinished,
  });

  final SplashService splashService;
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _safetyTimer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: widget.splashService.displayDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _finish();
          }
        });
    _controller.forward();
    _safetyTimer = Timer(const Duration(seconds: 5), _finish);
  }

  void _finish() {
    if (_completed || !mounted) {
      return;
    }
    _completed = true;
    _safetyTimer?.cancel();
    _safetyTimer = null;
    widget.onFinished();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: const Scaffold(
        backgroundColor: AppColors.splashBlue,
        body: _SplashBody(),
      ),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  static const _framePadding = 10.0;
  static const _sectionGap = 60.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_framePadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: _sectionGap,
          children: const [AdessoLogo(), _AppLogoGroup()],
        ),
      ),
    );
  }
}

class _AppLogoGroup extends StatelessWidget {
  const _AppLogoGroup();

  static const _titleGap = 20.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: _titleGap,
        children: [
          SignBridgeLogo(size: 200),
          Text(
            'SignBridge',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Klavika',
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 31 / 26,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
