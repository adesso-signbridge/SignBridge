import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sign_bridge/core/theme/app_colors.dart';
import 'package:sign_bridge/services/avatar/sign_asset_catalog.dart';
import 'package:sign_bridge/services/avatar/sign_playback_clip.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';
import 'package:sign_bridge/services/translate/sign_token.dart';
import 'package:video_player/video_player.dart';

/// Plays real signer clips from the Hugging Face–sourced asset catalog.
class SignVideoAvatarView extends StatefulWidget {
  const SignVideoAvatarView({
    super.key,
    required this.signSystem,
    required this.signSequence,
    required this.fallback,
    this.pulse = 0,
  });

  final SignLanguageSystem signSystem;
  final List<SignToken> signSequence;
  final Widget fallback;
  final int pulse;

  @override
  State<SignVideoAvatarView> createState() => _SignVideoAvatarViewState();
}

class _SignVideoAvatarViewState extends State<SignVideoAvatarView> {
  VideoPlayerController? _controller;
  var _catalogReady = false;
  var _videoReady = false;
  var _clipIndex = 0;
  var _playbackGeneration = 0;
  List<SignPlaybackClip> _clips = const [];
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(SignVideoAvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sequenceChanged =
        !_sameSequence(oldWidget.signSequence, widget.signSequence);
    final pulseChanged = oldWidget.pulse != widget.pulse;
    if (!_catalogReady) {
      return;
    }
    if (sequenceChanged ||
        oldWidget.signSystem != widget.signSystem ||
        pulseChanged) {
      unawaited(
        _syncPlayback(
          forceReplay: pulseChanged && !sequenceChanged,
        ),
      );
    }
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _playbackGeneration++;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_handleTick);
    controller?.dispose();
    super.dispose();
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

  Future<void> _bootstrap() async {
    await SignAssetCatalog.ensureLoaded();
    if (!mounted) {
      return;
    }
    setState(() => _catalogReady = true);
    await _syncPlayback(forceReplay: false);
  }

  Future<void> _syncPlayback({required bool forceReplay}) async {
    final clips = SignAssetCatalog.playbackClipsForSequence(
      widget.signSequence,
      widget.signSystem,
    );
    if (clips.isEmpty) {
      _playbackGeneration++;
      _watchdogTimer?.cancel();
      await _disposeController();
      if (mounted) {
        setState(() {
          _clips = const [];
          _videoReady = false;
        });
      }
      return;
    }

    final sameClipPaths = _clips.length == clips.length &&
        _pathsMatch(_clips, clips);
    if (!forceReplay && sameClipPaths) {
      return;
    }

    final previous = _clips;
    final appendedOnly = !forceReplay &&
        previous.isNotEmpty &&
        clips.length > previous.length &&
        _pathsSharePrefix(previous, clips);

    if (appendedOnly) {
      _clips = clips;
      await _playClipAt(previous.length);
      return;
    }

    _clips = clips;
    await _playClipAt(0);
  }

  bool _pathsMatch(List<SignPlaybackClip> a, List<SignPlaybackClip> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index].assetPath != b[index].assetPath) {
        return false;
      }
    }
    return true;
  }

  bool _pathsSharePrefix(
    List<SignPlaybackClip> previous,
    List<SignPlaybackClip> current,
  ) {
    if (current.length < previous.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].assetPath != current[index].assetPath) {
        return false;
      }
    }
    return true;
  }

  Future<void> _playClipAt(int index) async {
    if (index < 0 || index >= _clips.length) {
      return;
    }

    final generation = ++_playbackGeneration;
    _clipIndex = index;
    _watchdogTimer?.cancel();
    await _disposeController();

    final clip = _clips[index];
    final VideoPlayerController controller;
    if (clip.isRemote) {
      controller = VideoPlayerController.networkUrl(Uri.parse(clip.playbackUri));
    } else {
      controller = VideoPlayerController.asset(clip.playbackUri);
    }
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || generation != _playbackGeneration) {
        await controller.dispose();
        return;
      }
      controller.setLooping(false);
      controller.addListener(_handleTick);
      _startWatchdog(generation, controller);
      setState(() => _videoReady = true);
      await controller.play();
    } on Object catch (error) {
      debugPrint(
        '[SignBridge/SignVideo] failed ${clip.playbackUri} ($error); skipping',
      );
      await controller.dispose();
      if (_controller == controller) {
        _controller = null;
      }
      if (mounted && generation == _playbackGeneration) {
        await _playClipAt(index + 1);
      }
    }
  }

  void _startWatchdog(int generation, VideoPlayerController controller) {
    _watchdogTimer?.cancel();
    final duration = controller.value.duration;
    final timeout = duration == Duration.zero
        ? const Duration(seconds: 4)
        : duration + const Duration(milliseconds: 500);
    _watchdogTimer = Timer(timeout, () {
      if (!mounted || generation != _playbackGeneration) {
        return;
      }
      if (_controller != controller) {
        return;
      }
      unawaited(_advanceFrom(controller, generation));
    });
  }

  void _handleTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    if (value.hasError) {
      debugPrint('[SignBridge/SignVideo] player error: ${value.errorDescription}');
      unawaited(_advanceFrom(controller, _playbackGeneration));
      return;
    }
    if (value.isCompleted) {
      unawaited(_advanceFrom(controller, _playbackGeneration));
      return;
    }
    if (value.duration > Duration.zero &&
        value.position + const Duration(milliseconds: 80) >= value.duration) {
      unawaited(_advanceFrom(controller, _playbackGeneration));
    }
  }

  Future<void> _advanceFrom(
    VideoPlayerController controller,
    int generation,
  ) async {
    if (!mounted || generation != _playbackGeneration) {
      return;
    }
    if (_controller != controller) {
      return;
    }
    controller.removeListener(_handleTick);
    _watchdogTimer?.cancel();
    await _playClipAt(_clipIndex + 1);
  }

  Future<void> _disposeController() async {
    _watchdogTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller == null) {
      return;
    }
    controller.removeListener(_handleTick);
    await controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_catalogReady) {
      return widget.fallback;
    }

    final controller = _controller;
    if (!_videoReady || controller == null || !controller.value.isInitialized) {
      return widget.fallback;
    }

    final activeGloss = _clips.isEmpty ? '' : _clips[_clipIndex].token.gloss;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
      children: [
        widget.fallback,
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (activeGloss.isNotEmpty)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: _ActiveGlossChip(
              gloss: activeGloss,
              index: _clipIndex + 1,
              total: _clips.length,
            ),
          ),
      ],
    );
  }
}

class _ActiveGlossChip extends StatelessWidget {
  const _ActiveGlossChip({
    required this.gloss,
    required this.index,
    required this.total,
  });

  final String gloss;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.splashBlue.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$gloss  ($index/$total)',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
