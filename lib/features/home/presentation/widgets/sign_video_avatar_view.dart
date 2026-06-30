import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_bridge/services/avatar/sign_asset_catalog.dart';
import 'package:sign_bridge/services/avatar/sign_playback_clip.dart';
import 'package:sign_bridge/services/avatar/sign_video_cache.dart';
import 'package:sign_bridge/services/translate/sign_language_system.dart';
import 'package:sign_bridge/services/translate/sign_token.dart';
import 'package:video_player/video_player.dart';

/// Plays signer clips sequentially with streaming, disk cache, and crossfade.
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
  static const _crossfadeDuration = Duration(milliseconds: 120);

  VideoPlayerController? _controller;
  VideoPlayerController? _incomingController;
  VideoPlayerController? _prefetchedController;
  var _prefetchedIndex = -1;
  var _catalogReady = false;
  var _videoReady = false;
  var _clipIndex = 0;
  var _playbackGeneration = 0;
  var _incomingOpacity = 0.0;
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
    unawaited(_disposeController());
    unawaited(_disposeIncoming());
    unawaited(_disposePrefetch());
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
    final clips = await SignAssetCatalog.playbackClipsForSequenceAsync(
      widget.signSequence,
      widget.signSystem,
    );
    if (clips.isEmpty) {
      _playbackGeneration++;
      _watchdogTimer?.cancel();
      await _disposeController();
      await _disposeIncoming();
      await _disposePrefetch();
      if (mounted) {
        setState(() {
          _clips = const [];
          _videoReady = false;
          _incomingOpacity = 0;
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
    await _disposeIncoming();
    await _disposeController();

    VideoPlayerController? controller;
    if (_prefetchedIndex == index && _prefetchedController != null) {
      controller = _prefetchedController;
      _prefetchedController = null;
      _prefetchedIndex = -1;
    } else {
      await _disposePrefetch();
      controller = await _createControllerForClip(_clips[index]);
    }

    if (controller == null) {
      if (mounted && generation == _playbackGeneration) {
        await _playClipAt(index + 1);
      }
      return;
    }

    _controller = controller;

    try {
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      if (!mounted || generation != _playbackGeneration) {
        await controller.dispose();
        return;
      }
      controller.setLooping(false);
      controller.addListener(_handleTick);
      _startWatchdog(generation, controller);
      setState(() {
        _videoReady = true;
        _incomingOpacity = 0;
      });
      await controller.play();
      unawaited(_prefetchClipAt(index + 1, generation));
    } on Object catch (error) {
      debugPrint(
        '[SignBridge/SignVideo] failed ${_clips[index].playbackUri} ($error); skipping',
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

  Future<void> _crossfadeToPrefetched(int nextIndex, int generation) async {
    final outgoing = _controller;
    final incoming = _prefetchedController;
    if (incoming == null) {
      await _playClipAt(nextIndex);
      return;
    }

    _prefetchedController = null;
    _prefetchedIndex = -1;
    outgoing?.removeListener(_handleTick);
    _watchdogTimer?.cancel();

    if (!incoming.value.isInitialized) {
      await incoming.initialize();
    }
    if (!mounted || generation != _playbackGeneration) {
      return;
    }

    incoming.setLooping(false);
    await incoming.seekTo(Duration.zero);
    _incomingController = incoming;
    _incomingOpacity = 0;

    setState(() {});
    await incoming.play();

    const steps = 6;
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(
        Duration(
          milliseconds: _crossfadeDuration.inMilliseconds ~/ steps,
        ),
      );
      if (!mounted || generation != _playbackGeneration) {
        return;
      }
      setState(() => _incomingOpacity = step / steps);
    }

    await outgoing?.dispose();
    _controller = incoming;
    _incomingController = null;
    _incomingOpacity = 0;
    _clipIndex = nextIndex;
    incoming.addListener(_handleTick);
    _startWatchdog(generation, incoming);
    setState(() => _videoReady = true);
    unawaited(_prefetchClipAt(nextIndex + 1, generation));
  }

  Future<void> _prefetchClipAt(int index, int generation) async {
    if (index < 0 || index >= _clips.length) {
      return;
    }
    if (_prefetchedIndex == index && _prefetchedController != null) {
      return;
    }

    await _disposePrefetch();
    final controller = await _createControllerForClip(
      _clips[index],
      prefetch: true,
    );
    if (controller == null) {
      return;
    }
    if (!mounted || generation != _playbackGeneration) {
      await controller.dispose();
      return;
    }
    _prefetchedController = controller;
    _prefetchedIndex = index;
  }

  Future<VideoPlayerController?> _createControllerForClip(
    SignPlaybackClip clip, {
    bool prefetch = false,
  }) async {
    if (!clip.isRemote) {
      debugPrint(
        '[SignBridge/SignVideo] skipping non-remote clip ${clip.assetPath}',
      );
      return null;
    }

    final source = prefetch
        ? await SignVideoPlaybackSource.resolveForPrefetch(clip)
        : await SignVideoPlaybackSource.resolve(clip);

    try {
      final controller = _controllerForSource(source);
      await controller.initialize();
      return controller;
    } on Object catch (error) {
      debugPrint('[SignBridge/SignVideo] playback failed $source ($error)');
      return null;
    }
  }

  VideoPlayerController _controllerForSource(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(source));
    }
    return VideoPlayerController.file(File(source));
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

    final nextIndex = _clipIndex + 1;
    if (nextIndex < _clips.length &&
        _prefetchedIndex == nextIndex &&
        _prefetchedController != null) {
      await _crossfadeToPrefetched(nextIndex, generation);
      return;
    }
    await _playClipAt(nextIndex);
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

  Future<void> _disposeIncoming() async {
    final controller = _incomingController;
    _incomingController = null;
    _incomingOpacity = 0;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _disposePrefetch() async {
    final controller = _prefetchedController;
    _prefetchedController = null;
    _prefetchedIndex = -1;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Widget _videoLayer(VideoPlayerController controller, double opacity) {
    final videoSize = controller.value.size;
    final hasVideoSize = videoSize.width > 0 && videoSize.height > 0;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: hasVideoSize ? videoSize.width : 16,
            height: hasVideoSize ? videoSize.height : 9,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_catalogReady) {
      return widget.fallback;
    }

    if (_clips.isNotEmpty && !_videoReady) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          widget.fallback,
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      );
    }

    final controller = _controller;
    if (!_videoReady || controller == null || !controller.value.isInitialized) {
      return widget.fallback;
    }

    final incoming = _incomingController;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(child: _videoLayer(controller, 1 - _incomingOpacity)),
        if (incoming != null && incoming.value.isInitialized)
          Positioned.fill(child: _videoLayer(incoming, _incomingOpacity)),
      ],
    );
  }
}
