import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/home/home_service.dart';
import '../../../../services/translate/sign_capture_result.dart';
import '../../../../services/translate/talk_listen_result.dart';
import 'sign_camera_recorder.dart';
import 'talk_session_content.dart';

class TalkSignRecordingContent extends StatefulWidget {
  const TalkSignRecordingContent({
    super.key,
    required this.uiCopy,
    this.heardResult,
    required this.isRecording,
    required this.onRecordingStopped,
    required this.onCameraError,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult? heardResult;
  final bool isRecording;
  final ValueChanged<String> onRecordingStopped;
  final ValueChanged<String> onCameraError;

  @override
  State<TalkSignRecordingContent> createState() =>
      _TalkSignRecordingContentState();
}

class _TalkSignRecordingContentState extends State<TalkSignRecordingContent> {
  final _cameraController = SignCameraRecorderController();

  @override
  void initState() {
    super.initState();
    _cameraController.addListener(_onCameraControllerChanged);
  }

  @override
  void dispose() {
    _cameraController.removeListener(_onCameraControllerChanged);
    _cameraController.dispose();
    super.dispose();
  }

  void _onCameraControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkSignHeardSection(
          heardResult: widget.heardResult,
          uiCopy: widget.uiCopy,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.talkSessionStatusBottom,
            ),
            child: TalkSignRecordingStatusBubble(
              label: widget.uiCopy.recordingSignsLabel,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.talkSessionStatusBottom),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cameraHeight = constraints.maxHeight.clamp(
                160.0,
                AppSpacing.talkSignCameraCardHeight,
              );
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: cameraHeight,
                  child: SignCameraStageFrame(
                    overlay: null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SignCameraRecorder(
                          controller: _cameraController,
                          isRecording: widget.isRecording,
                          onRecordingStopped: widget.onRecordingStopped,
                          onError: widget.onCameraError,
                        ),
                        if (widget.isRecording)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: 14),
                              child: SignRecordingBadge(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TalkSignAnalyzingContent extends StatelessWidget {
  const TalkSignAnalyzingContent({
    super.key,
    required this.uiCopy,
    this.heardResult,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult? heardResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkSignHeardSection(heardResult: heardResult, uiCopy: uiCopy),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.talkSessionStatusBottom,
              bottom: AppSpacing.talkSessionStatusBottom,
            ),
            child: TalkSignAnalyzingStatusBubble(
              label: uiCopy.analyzingSignsLabel,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class TalkSignSpokenContent extends StatelessWidget {
  const TalkSignSpokenContent({
    super.key,
    required this.uiCopy,
    this.heardResult,
    required this.signResult,
    required this.onReplay,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult? heardResult;
  final SignCaptureResult signResult;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkSignHeardSection(heardResult: heardResult, uiCopy: uiCopy),
        if (signResult.hasGloss) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.talkSessionStatusBottom,
              ),
              child: TalkSignGlossCapturedRow(
                label: uiCopy.signsCapturedLabel,
                glossSequence: signResult.glossSequence,
              ),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: signResult.hasGloss
                  ? AppSpacing.talkSessionStatusBottom
                  : AppSpacing.talkSessionStatusBottom,
            ),
            child: TalkSignSpokenMessage(
              transcript: signResult.text,
              metaLabel:
                  '${uiCopy.spokenLabel} · ${signResult.formattedDuration()}',
              replayLabel: uiCopy.replayLabel,
              onReplay: onReplay,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

/// One chip per gloss token so each captured sign is visible before TTS.
class TalkSignGlossCapturedRow extends StatelessWidget {
  const TalkSignGlossCapturedRow({
    super.key,
    required this.label,
    required this.glossSequence,
  });

  final String label;
  final List<String> glossSequence;

  @override
  Widget build(BuildContext context) {
    return TalkSignRightStatusBubble(
      backgroundColor: AppColors.talkSignAnalyzingBubbleBg,
      borderColor: AppColors.talkSignAnalyzingBubbleBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Klavika',
              fontWeight: FontWeight.w400,
              fontSize: 11,
              height: 16 / 11,
              color: AppColors.talkMutedText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final gloss in glossSequence)
                TalkSignGlossChip(token: gloss),
            ],
          ),
        ],
      ),
    );
  }
}

class TalkSignGlossChip extends StatelessWidget {
  const TalkSignGlossChip({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.splashBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.splashBlue.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          token,
          style: const TextStyle(
            fontFamily: 'Klavika',
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 16 / 12,
            color: AppColors.splashBlue,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class TalkSignHeardSection extends StatelessWidget {
  const TalkSignHeardSection({
    super.key,
    required this.heardResult,
    required this.uiCopy,
  });

  final TalkListenResult? heardResult;
  final HomeUiCopy uiCopy;

  @override
  Widget build(BuildContext context) {
    if (heardResult == null || !heardResult!.hasTranscript) {
      return const SizedBox.shrink();
    }

    return TalkHeardSummaryHeader(
      transcript: heardResult!.fullTranscript,
      metaLabel: '${uiCopy.heardLabel} · ${heardResult!.heardDuration}',
    );
  }
}

/// Shared row for sign-flow status bubbles so long labels wrap instead of overflowing.
class TalkSignStatusLabelRow extends StatelessWidget {
  const TalkSignStatusLabelRow({
    super.key,
    required this.leading,
    required this.label,
    required this.textStyle,
  });

  final Widget leading;
  final String label;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth -
        (AppSpacing.talkContentPaddingH * 2) -
        (AppSpacing.talkSessionBubblePaddingH * 2);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: AppSpacing.talkSignStatusBubbleGap),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Blue right-aligned bubble shown while recording signs.
class TalkSignRecordingStatusBubble extends StatelessWidget {
  const TalkSignRecordingStatusBubble({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TalkSignRightStatusBubble(
      backgroundColor: AppColors.splashBlue,
      borderColor: Colors.transparent,
      child: TalkSignStatusLabelRow(
        leading: Container(
          width: AppSpacing.talkSignRecordingDotSize,
          height: AppSpacing.talkSignRecordingDotSize,
          decoration: const BoxDecoration(
            color: AppColors.talkSignRecordingDot,
            shape: BoxShape.circle,
          ),
        ),
        label: label,
        textStyle: const TextStyle(
          fontFamily: 'Klavika',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          height: 20 / 13,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// Light gray right-aligned bubble shown while analyzing signs.
class TalkSignAnalyzingStatusBubble extends StatelessWidget {
  const TalkSignAnalyzingStatusBubble({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TalkSignRightStatusBubble(
      backgroundColor: AppColors.talkSignAnalyzingBubbleBg,
      borderColor: AppColors.talkSignAnalyzingBubbleBorder,
      child: TalkSignStatusLabelRow(
        leading: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.57,
            color: AppColors.splashBlue.withValues(alpha: 0.55),
          ),
        ),
        label: label,
        textStyle: const TextStyle(
          fontFamily: 'Klavika',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          height: 20 / 13,
          color: AppColors.phraseCategoryText,
        ),
      ),
    );
  }
}

/// Blue spoken transcript bubble with inline replay pill and meta row.
class TalkSignSpokenMessage extends StatelessWidget {
  const TalkSignSpokenMessage({
    super.key,
    required this.transcript,
    required this.metaLabel,
    required this.replayLabel,
    required this.onReplay,
  });

  final String transcript;
  final String metaLabel;
  final String replayLabel;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        TalkSignRightStatusBubble(
          backgroundColor: AppColors.splashBlue,
          borderColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transcript,
                style: const TextStyle(
                  fontFamily: 'Klavika',
                  fontWeight: FontWeight.w400,
                  fontSize: AppSpacing.talkSessionTranscriptFont,
                  height: AppSpacing.talkSessionTranscriptLineHeight,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.talkSessionMetaTop),
              TalkReplayButton(label: replayLabel, onTap: onReplay),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.talkSessionMetaPaddingTop,
            right: AppSpacing.talkSessionMetaPaddingLeft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metaLabel,
                style: const TextStyle(
                  fontFamily: 'Klavika',
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                  height: 1.5,
                  color: AppColors.talkMutedText,
                ),
              ),
              const SizedBox(width: AppSpacing.talkSessionMetaDotGap),
              Container(
                width: AppSpacing.talkSessionMetaDotSize,
                height: AppSpacing.talkSessionMetaDotSize,
                decoration: const BoxDecoration(
                  color: AppColors.talkSpokenActiveDot,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TalkSignRightStatusBubble extends StatelessWidget {
  const TalkSignRightStatusBubble({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor == Colors.transparent
            ? null
            : Border.all(color: borderColor, width: 1.04),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.talkSessionBubbleRadiusLarge),
          topRight: Radius.circular(AppSpacing.talkSessionBubbleRadiusSmall),
          bottomRight: Radius.circular(AppSpacing.talkSessionBubbleRadiusLarge),
          bottomLeft: Radius.circular(AppSpacing.talkSessionBubbleRadiusLarge),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.talkSessionBubblePaddingH,
          AppSpacing.talkSessionBubblePaddingTop,
          AppSpacing.talkSessionBubblePaddingH,
          AppSpacing.talkSessionBubblePaddingBottom,
        ),
        child: child,
      ),
    );
  }
}

class TalkHeardSummaryHeader extends StatelessWidget {
  const TalkHeardSummaryHeader({
    super.key,
    required this.transcript,
    required this.metaLabel,
  });

  final String transcript;
  final String metaLabel;

  @override
  Widget build(BuildContext context) {
    return TalkFullTranscriptHeader(
      transcript: transcript,
      metaLabel: metaLabel,
    );
  }
}

class TalkReplayButton extends StatelessWidget {
  const TalkReplayButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.talkSignReplayPillRadius),
      child: InkWell(
        key: const Key('talk_replay_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppSpacing.talkSignReplayPillRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.replay_rounded,
                size: 12,
                color: AppColors.splashBlue,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Klavika',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  height: 1.5,
                  color: AppColors.splashBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
