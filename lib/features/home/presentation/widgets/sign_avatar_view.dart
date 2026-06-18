import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';

import 'asl_sign_overlay.dart';
import 'cwasa_avatar_view.dart';

/// Renders the signing avatar with illustration + animated sign overlay.
class SignAvatarView extends StatelessWidget {
  const SignAvatarView({
    super.key,
    required this.signTokenId,
    required this.signSystem,
    required this.fallbackAsset,
    required this.signingWord,
    this.signPulse = 0,
    this.showNative = true,
  });

  final String signTokenId;
  final SignLanguageSystem signSystem;
  final String fallbackAsset;
  final String signingWord;
  final int signPulse;
  final bool showNative;

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  bool get _useCwasa {
    if (!showNative || kIsWeb || _isFlutterTest) {
      return false;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return false;
    }
    return signTokenId != SignTokenIds.thinking;
  }

  bool get _showOverlay {
    if (_useCwasa || !showNative || kIsWeb || _isFlutterTest) {
      return false;
    }
    return signTokenId != SignTokenIds.thinking;
  }

  @override
  Widget build(BuildContext context) {
    if (_useCwasa) {
      return CwasaAvatarView(
        glossPhrase: signingWord,
        pulse: signPulse,
      );
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
      children: [
        Image.asset(
          fallbackAsset,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
        ),
        if (_showOverlay)
          AslSignOverlay(
            key: ValueKey('$signTokenId-$signPulse'),
            signTokenId: signTokenId,
            gloss: signingWord,
            pulse: signPulse,
          ),
      ],
    );
  }
}

/// Stable sign ids shared with native avatar pose tables.
abstract final class SignTokenIds {
  static const thinking = 'thinking';
}
