import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SignBridgeLogo extends StatelessWidget {
  const SignBridgeLogo({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/splash/splash_logo.svg',
      width: size,
      height: size,
    );
  }
}
