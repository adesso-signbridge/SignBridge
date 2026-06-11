import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AdessoLogo extends StatelessWidget {
  const AdessoLogo({super.key, this.width = 51, this.height = 62});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/splash/adesso_logo.svg',
      width: width,
      height: height,
    );
  }
}
