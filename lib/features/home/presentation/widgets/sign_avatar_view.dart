import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_bridge/services/avatar/sign_playback_config.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';
import 'package:sign_bridge/services/translate/sign_token.dart';

import 'asl_sign_overlay.dart';
import 'sign_video_avatar_view.dart';

/// Renders the signing avatar with Hugging Face signer videos when available.
class SignAvatarView extends StatelessWidget {
  const SignAvatarView({
    super.key,
    required this.signTokenId,
    required this.signSystem,
    required this.fallbackAsset,
    required this.signingWord,
    this.signSequence = const [],
    this.signPulse = 0,
    this.showNative = true,
    this.generatedVideoUrl,
    this.generatedImageUrls = const [],
    this.veoOnly = false,
  });

  final String signTokenId;
  final SignLanguageSystem signSystem;
  final String fallbackAsset;
  final String signingWord;
  final List<SignToken> signSequence;
  final int signPulse;
  final bool showNative;
  final String? generatedVideoUrl;
  final List<String> generatedImageUrls;
  final bool veoOnly;

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  bool get _useSignerVideo {
    if (SignPlaybackConfig.imagesOnly) {
      return false;
    }
    if (!showNative || kIsWeb || _isFlutterTest) {
      return false;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return false;
    }
    return signTokenId != SignTokenIds.thinking;
  }

  bool get _showOverlay {
    if (SignPlaybackConfig.imagesOnly) {
      return false;
    }
    if (_useSignerVideo || !showNative || kIsWeb || _isFlutterTest) {
      return false;
    }
    return signTokenId != SignTokenIds.thinking;
  }

  bool get _hasGeneratedImages =>
      generatedImageUrls.any((url) => url.trim().isNotEmpty);

  Widget _buildFallback() {
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

  @override
  Widget build(BuildContext context) {
    if (_hasGeneratedImages) {
      return GeneratedGlossImageView(
        imageUrls: generatedImageUrls,
        pulse: signPulse,
        fallback: _buildFallback(),
      );
    }

    if (!SignPlaybackConfig.imagesOnly && (veoOnly || _useSignerVideo)) {
      return SignVideoAvatarView(
        signSystem: signSystem,
        signSequence: veoOnly ? const [] : signSequence,
        pulse: signPulse,
        generatedVideoUrl: generatedVideoUrl,
        veoOnly: veoOnly,
        fallback: _buildFallback(),
      );
    }

    return _buildFallback();
  }
}

/// Cycles through Nano Banana 2D images, one per gloss.
class GeneratedGlossImageView extends StatefulWidget {
  const GeneratedGlossImageView({
    super.key,
    required this.imageUrls,
    required this.fallback,
    this.pulse = 0,
    this.dwell = const Duration(milliseconds: 1600),
  });

  final List<String> imageUrls;
  final Widget fallback;
  final int pulse;
  final Duration dwell;

  @override
  State<GeneratedGlossImageView> createState() =>
      _GeneratedGlossImageViewState();
}

class _GeneratedGlossImageViewState extends State<GeneratedGlossImageView> {
  Timer? _timer;
  var _index = 0;
  late List<String> _urls;

  @override
  void initState() {
    super.initState();
    _urls = _normalize(widget.imageUrls);
    _restartCycle();
  }

  @override
  void didUpdateWidget(GeneratedGlossImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _normalize(widget.imageUrls);
    final urlsChanged = !_sameUrls(_urls, next);
    if (urlsChanged || oldWidget.pulse != widget.pulse) {
      _urls = next;
      _index = 0;
      _restartCycle();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> _normalize(List<String> raw) {
    return raw
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  bool _sameUrls(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  void _restartCycle() {
    _timer?.cancel();
    if (_urls.length <= 1) {
      return;
    }
    _timer = Timer.periodic(widget.dwell, (_) {
      if (!mounted || _urls.isEmpty) {
        return;
      }
      setState(() => _index = (_index + 1) % _urls.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return widget.fallback;
    }

    final url = _urls[_index.clamp(0, _urls.length - 1)];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Image.network(
        url,
        key: ValueKey('$url-$_index-${widget.pulse}'),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return widget.fallback;
        },
        errorBuilder: (context, error, stackTrace) => widget.fallback,
      ),
    );
  }
}

/// Stable sign ids shared with native avatar pose tables.
abstract final class SignTokenIds {
  static const thinking = 'thinking';
}
