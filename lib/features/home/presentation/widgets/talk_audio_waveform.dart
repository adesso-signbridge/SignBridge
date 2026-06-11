import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/translate/audio_level_normalizer.dart';

/// Live microphone waveform driven by normalized audio level (0–1).
class TalkAudioWaveform extends StatefulWidget {
  const TalkAudioWaveform({
    super.key,
    required this.level,
    this.live = true,
    this.decaying = false,
  });

  /// Current microphone intensity from [TranslateService.audioLevelUpdates].
  final double level;

  /// When true, bars track [level] from the mic stream.
  final bool live;

  /// When true (e.g. after stop), bars decay to idle without a decorative loop.
  final bool decaying;

  @override
  State<TalkAudioWaveform> createState() => _TalkAudioWaveformState();
}

class _TalkAudioWaveformState extends State<TalkAudioWaveform>
    with SingleTickerProviderStateMixin {
  static const _barOpacities = [
    0.75,
    0.49,
    0.62,
    0.667,
    0.945,
    0.408,
    0.765,
    0.86,
    0.66,
    0.553,
    0.82,
    0.635,
    0.757,
    0.95,
    0.784,
    0.76,
  ];

  late final List<double> _samples;
  late final AnimationController _idleController;
  Timer? _liveTick;

  @override
  void initState() {
    super.initState();
    _samples = List<double>.generate(
      AppSpacing.talkSessionWaveformBarCount,
      (_) => 0.04,
    );
    if (widget.live || widget.decaying) {
      _pushSample(widget.decaying ? 0 : widget.level);
    }
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncTickers();
  }

  @override
  void dispose() {
    _liveTick?.cancel();
    _idleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TalkAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live != oldWidget.live ||
        widget.decaying != oldWidget.decaying) {
      _syncTickers();
    }
  }

  void _syncTickers() {
    _liveTick?.cancel();
    _liveTick = null;
    if (widget.live || widget.decaying) {
      _idleController.stop();
      _liveTick = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted) {
          return;
        }
        _pushSample(widget.decaying ? 0 : widget.level);
        setState(() {});
      });
      return;
    }
    if (!_idleController.isAnimating) {
      _idleController.repeat();
    }
  }

  void _pushSample(double level) {
    final clamped = level.clamp(0.0, 1.0);
    _samples.removeAt(0);
    _samples.add(clamped);
  }

  double _barHeight(int index) {
    const minHeight = 4.0;
    const maxHeight = 27.0;

    if (widget.live || widget.decaying) {
      final weight = AudioLevelNormalizer.barWeight(
        index,
        AppSpacing.talkSessionWaveformBarCount,
      );
      final sample = _samples[index] * weight;
      return minHeight + sample * (maxHeight - minHeight);
    }

    final phase = (_idleController.value * 2 * math.pi) + (index * 0.55);
    final idle = 0.04 + math.sin(phase).abs() * 0.06;
    return minHeight + idle * (maxHeight - minHeight);
  }

  @override
  Widget build(BuildContext context) {
    final bars = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(AppSpacing.talkSessionWaveformBarCount, (index) {
        final height = _barHeight(index);
        final opacity = _barOpacities[index % _barOpacities.length];
        return Container(
          key: Key('talk_waveform_bar_$index'),
          width: AppSpacing.talkSessionWaveformBarWidth,
          height: height,
          margin: EdgeInsets.only(
            right: index == AppSpacing.talkSessionWaveformBarCount - 1
                ? 0
                : AppSpacing.talkSessionWaveformGap,
          ),
          decoration: BoxDecoration(
            color: AppColors.splashBlue.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );

    return SizedBox(
      height: AppSpacing.talkSessionWaveformHeight,
      child: widget.live || widget.decaying
          ? bars
          : AnimatedBuilder(
              animation: _idleController,
              builder: (_, _) => bars,
            ),
    );
  }
}
