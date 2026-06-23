import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sign_bridge/core/theme/app_colors.dart';
import 'package:sign_bridge/services/avatar/cwasa_sigml_catalog.dart';
import 'package:sign_bridge/services/translate/sign_token.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Shared CWASA runtime so the WebView survives session UI phase changes.
final class CwasaAvatarRuntime {
  CwasaAvatarRuntime._();

  static WebViewController? _controller;
  static var ready = false;
  static var attachCount = 0;
  static final readyListeners = <VoidCallback>{};

  static WebViewController controller() {
    return _controller ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.talkScreenBackground)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'SignBridgeFlutter',
        onMessageReceived: (message) {
          if (message.message != 'ready' || ready) {
            return;
          }
          ready = true;
          for (final listener in readyListeners.toList()) {
            listener();
          }
        },
      )
      ..loadFlutterAsset('assets/cwasa/cwasa_avatar.html');
  }

  static void retain() {
    attachCount++;
  }

  static void release() {
    if (attachCount > 0) {
      attachCount--;
    }
  }

  static void onReady(VoidCallback listener) {
    if (ready) {
      listener();
      return;
    }
    readyListeners.add(listener);
  }

  static void removeReadyListener(VoidCallback listener) {
    readyListeners.remove(listener);
  }
}

/// Embeds the UEA CWASA WebGL signing avatar inside a WebView.
class CwasaAvatarView extends StatefulWidget {
  const CwasaAvatarView({
    super.key,
    required this.glossPhrase,
    this.signSequence = const [],
    this.pulse = 0,
  });

  final String glossPhrase;
  final List<SignToken> signSequence;
  final int pulse;

  @override
  State<CwasaAvatarView> createState() => _CwasaAvatarViewState();
}

class _CwasaAvatarViewState extends State<CwasaAvatarView> {
  late final WebViewController _controller;
  var _lastScheduledPhrase = '';
  var _lastScheduledSequence = const <SignToken>[];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    CwasaAvatarRuntime.retain();
    _controller = CwasaAvatarRuntime.controller();
    CwasaAvatarRuntime.onReady(_handleReady);
    _schedulePlayback(immediate: CwasaAvatarRuntime.ready);
  }

  @override
  void didUpdateWidget(CwasaAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glossPhrase != widget.glossPhrase ||
        !_sameSequence(oldWidget.signSequence, widget.signSequence)) {
      _schedulePlayback();
    } else if (oldWidget.pulse != widget.pulse &&
        widget.glossPhrase.trim().isNotEmpty) {
      _schedulePlayback(immediate: true, forceReplay: true);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    CwasaAvatarRuntime.removeReadyListener(_handleReady);
    CwasaAvatarRuntime.release();
    super.dispose();
  }

  void _handleReady() {
    if (!mounted) {
      return;
    }
    _schedulePlayback(immediate: true);
  }

  void _schedulePlayback({bool immediate = false, bool forceReplay = false}) {
    _debounceTimer?.cancel();
    if (immediate) {
      unawaited(_syncPlayback(forceReplay: forceReplay));
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_syncPlayback(forceReplay: false));
    });
  }

  bool _sameSequence(List<SignToken> a, List<SignToken> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      final left = a[index];
      final right = b[index];
      if (left.id != right.id || left.gloss != right.gloss) {
        return false;
      }
    }
    return true;
  }

  List<SignToken> _playableSequence(List<SignToken> sequence) {
    return sequence
        .where((token) => token.id != SignToken.thinking.id)
        .toList(growable: false);
  }

  Future<void> _syncPlayback({required bool forceReplay}) async {
    if (!CwasaAvatarRuntime.ready) {
      return;
    }

    final playableSequence = _playableSequence(widget.signSequence);
    if (playableSequence.isNotEmpty) {
      await _syncSequencePlayback(
        playableSequence,
        forceReplay: forceReplay,
      );
      return;
    }

    final phrase = widget.glossPhrase.trim();
    if (phrase.isEmpty || phrase == '...') {
      _lastScheduledPhrase = '';
      _lastScheduledSequence = const [];
      return;
    }

    final remoteUrl = CwasaSigmlCatalog.remoteUrlForPhrase(phrase);
    if (remoteUrl != null) {
      _lastScheduledPhrase = phrase;
      await _controller.runJavaScript(
        'window.SignBridge.playSiGMLUrl(${jsonEncode(remoteUrl)});',
      );
      return;
    }

    final previous = _lastScheduledPhrase.trim();
    final replaced =
        previous.isNotEmpty &&
        !phrase.startsWith(previous) &&
        previous != phrase;
    final extended = previous.isNotEmpty && phrase.startsWith(previous);

    if (forceReplay || replaced || previous.isEmpty) {
      final document = CwasaSigmlCatalog.buildDocument(phrase);
      if (document == null) {
        return;
      }
      _lastScheduledPhrase = phrase;
      _lastScheduledSequence = const [];
      await _controller.runJavaScript(
        'window.SignBridge.resetAndPlayBatch(${jsonEncode(document)});',
      );
      return;
    }

    if (!extended || phrase == previous) {
      return;
    }

    final deltaDocument = CwasaSigmlCatalog.buildDocumentForDelta(
      previousPhrase: previous,
      currentPhrase: phrase,
    );
    if (deltaDocument == null) {
      _lastScheduledPhrase = phrase;
      return;
    }

    _lastScheduledPhrase = phrase;
    await _controller.runJavaScript(
      'window.SignBridge.enqueueBatch(${jsonEncode(deltaDocument)});',
    );
  }

  Future<void> _syncSequencePlayback(
    List<SignToken> sequence, {
    required bool forceReplay,
  }) async {
    final previous = _lastScheduledSequence;

    if (forceReplay ||
        previous.isEmpty ||
        sequence.length < previous.length) {
      final document = CwasaSigmlCatalog.buildDocumentFromSequence(sequence);
      if (document == null) {
        return;
      }
      _lastScheduledSequence = sequence;
      _lastScheduledPhrase = '';
      await _controller.runJavaScript(
        'window.SignBridge.resetAndPlayBatch(${jsonEncode(document)});',
      );
      return;
    }

    final delta = CwasaSigmlCatalog.sequenceTokenDelta(previous, sequence);
    if (delta.isEmpty) {
      return;
    }

    if (delta.length == sequence.length - previous.length) {
      final deltaDocument = CwasaSigmlCatalog.buildDocumentFromSequence(delta);
      if (deltaDocument == null) {
        _lastScheduledSequence = sequence;
        return;
      }
      _lastScheduledSequence = sequence;
      await _controller.runJavaScript(
        'window.SignBridge.enqueueBatch(${jsonEncode(deltaDocument)});',
      );
      return;
    }

    final document = CwasaSigmlCatalog.buildDocumentFromSequence(sequence);
    if (document == null) {
      return;
    }
    _lastScheduledSequence = sequence;
    _lastScheduledPhrase = '';
    await _controller.runJavaScript(
      'window.SignBridge.resetAndPlayBatch(${jsonEncode(document)});',
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
