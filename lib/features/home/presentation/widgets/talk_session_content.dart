import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/home/home_service.dart';
import '../../../../services/translate/translate_service.dart';
import 'sign_avatar_view.dart';

class TalkListeningContent extends StatelessWidget {
  const TalkListeningContent({
    super.key,
    required this.uiCopy,
    this.liveResult,
    this.signPulse = 0,
    this.isRefreshingGloss = false,
    this.cloudGlossWord,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult? liveResult;
  final int signPulse;
  final bool isRefreshingGloss;
  final String? cloudGlossWord;

  bool get _hasCaption => liveResult?.fullTranscript.isNotEmpty ?? false;

  String? get _chipWord {
    if (cloudGlossWord != null && cloudGlossWord!.trim().isNotEmpty) {
      return cloudGlossWord;
    }
    if (isRefreshingGloss || _hasCaption) {
      return uiCopy.signingListeningWord;
    }
    return null;
  }

  bool get _hasCloudGloss =>
      cloudGlossWord != null && cloudGlossWord!.trim().isNotEmpty;

  String get _avatarSignTokenId {
    if (!_hasCloudGloss) {
      return SignTokenIds.thinking;
    }
    return liveResult?.signTokenId ?? SignTokenIds.thinking;
  }

  String get _avatarSigningWord {
    if (!_hasCloudGloss) {
      return _hasCaption ? uiCopy.signingListeningWord : '';
    }
    return cloudGlossWord!;
  }

  String get _avatarAsset => _hasCaption
      ? 'assets/home/talk_flow/illu_signing.png'
      : 'assets/home/talk_flow/illu_listening.png';

  @override
  Widget build(BuildContext context) {
    return _FigmaSessionColumn(
      header: Padding(
        padding: const EdgeInsets.only(
          bottom: AppSpacing.talkSessionStatusBottom,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: double.infinity,
            child: _hasCaption
                ? _TranscriptBubble(transcript: liveResult!.fullTranscript)
                : _SessionStatusBubble(label: uiCopy.listeningLabel),
          ),
        ),
      ),
      stage: (height) => _TalkAvatarCardStage(
        height: height,
        fallbackAsset: _avatarAsset,
        signTokenId: _avatarSignTokenId,
        signSystem: liveResult?.signSystem ?? SignLanguageSystem.asl,
        signingWord: _avatarSigningWord,
        signPulse: signPulse,
        signingChip: _OverlaySigningChip(
          prefix: uiCopy.signingPrefix,
          word: _chipWord,
          systemLabel: cloudGlossWord != null ? liveResult?.signSystem.label : null,
        ),
      ),
    );
  }
}

class TalkHeardContent extends StatelessWidget {
  const TalkHeardContent({
    super.key,
    required this.uiCopy,
    required this.result,
    this.signPulse = 0,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult result;
  final int signPulse;

  @override
  Widget build(BuildContext context) {
    return _FigmaSessionColumn(
      header: _PartialTranscriptHeader(transcript: result.transcript),
      stage: (height) => _TalkAvatarCardStage(
        height: height,
        fallbackAsset: 'assets/home/talk_flow/illu_signing.png',
        signTokenId: result.signTokenId,
        signSystem: result.signSystem,
        signingWord: result.signingWord,
        signPulse: signPulse,
        signingChip: _OverlaySigningChip(
          prefix: uiCopy.signingPrefix,
          word: result.signingWord,
          systemLabel: result.signSystem.label,
        ),
      ),
    );
  }
}

class TalkSigningContent extends StatelessWidget {
  const TalkSigningContent({
    super.key,
    required this.uiCopy,
    required this.result,
    this.signPulse = 0,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult result;
  final int signPulse;

  @override
  Widget build(BuildContext context) {
    return _FigmaSessionColumn(
      header: _FullTranscriptHeader(
        transcript: result.fullTranscript,
        metaLabel: '${uiCopy.heardLabel} · ${result.heardDuration}',
      ),
      stage: (height) => _TalkAvatarCardStage(
        height: height,
        fallbackAsset: 'assets/home/talk_flow/illu_signing.png',
        signTokenId: result.signTokenId,
        signSystem: result.signSystem,
        signingWord: result.signingWord,
        signPulse: signPulse,
        signingChip: _OverlaySigningChip(
          prefix: uiCopy.signingPrefix,
          word: result.signingWord,
          systemLabel: result.signSystem.label,
        ),
      ),
    );
  }
}

class TalkStoppedContent extends StatelessWidget {
  const TalkStoppedContent({
    super.key,
    required this.uiCopy,
    required this.result,
    this.signPulse = 0,
    this.isRefreshingGloss = false,
    this.cloudGlossWord,
  });

  final HomeUiCopy uiCopy;
  final TalkListenResult result;
  final int signPulse;
  final bool isRefreshingGloss;
  final String? cloudGlossWord;

  String? get _chipWord {
    if (cloudGlossWord != null && cloudGlossWord!.trim().isNotEmpty) {
      return cloudGlossWord;
    }
    if (isRefreshingGloss || result.hasTranscript) {
      return uiCopy.signingListeningWord;
    }
    return null;
  }

  bool get _hasCloudGloss =>
      cloudGlossWord != null && cloudGlossWord!.trim().isNotEmpty;

  String get _avatarSigningWord {
    if (_hasCloudGloss) {
      return cloudGlossWord!;
    }
    return result.hasTranscript ? uiCopy.signingListeningWord : '';
  }

  String get _avatarSignTokenId {
    if (_hasCloudGloss) {
      return result.signTokenId;
    }
    return SignTokenIds.thinking;
  }

  @override
  Widget build(BuildContext context) {
    return _FigmaSessionColumn(
      header: _FullTranscriptHeader(
        transcript: result.hasTranscript
            ? result.fullTranscript
            : uiCopy.noSpeechDetectedLabel,
        metaLabel: result.hasTranscript
            ? '${uiCopy.heardLabel} · ${result.heardDuration}'
            : result.heardDuration,
      ),
      stage: (height) => _TalkAvatarCardStage(
        height: height,
        fallbackAsset: 'assets/home/talk_flow/illu_signing.png',
        signTokenId: _avatarSignTokenId,
        signSystem: result.signSystem,
        signingWord: _avatarSigningWord,
        signPulse: signPulse,
        signingChip: _OverlaySigningChip(
          prefix: uiCopy.signingPrefix,
          word: _chipWord,
          systemLabel: cloudGlossWord != null ? result.signSystem.label : null,
        ),
      ),
    );
  }
}

class TalkClearHistoryButton extends StatelessWidget {
  const TalkClearHistoryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.talkSessionClearHistoryRowHeight,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('talk_clear_history_button'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              AppSpacing.talkSessionClearHistoryRadius,
            ),
            child: Ink(
              width: AppSpacing.talkSessionClearHistoryWidth,
              height: AppSpacing.talkSessionClearHistoryHeight,
              decoration: BoxDecoration(
                color: AppColors.talkClearHistoryBackground,
                border: Border.all(
                  color: AppColors.talkStopRed,
                  width: AppSpacing.talkSessionClearHistoryBorderWidth,
                ),
                borderRadius: BorderRadius.circular(
                  AppSpacing.talkSessionClearHistoryRadius,
                ),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: AppSpacing.talkSessionClearHistoryIconSize,
                        height: AppSpacing.talkSessionClearHistoryIconSize,
                        child: Image.asset(
                          'assets/home/icon_clear_history.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(
                        width: AppSpacing.talkSessionClearHistoryGap,
                      ),
                      SizedBox(
                        height: AppSpacing.talkSessionClearHistoryIconSize,
                        child: Center(
                          child: Text(
                            label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: const TextStyle(
                              fontFamily: 'Klavika',
                              fontWeight: FontWeight.w700,
                              fontSize:
                                  AppSpacing.talkSessionClearHistoryFontSize,
                              height: 1,
                              leadingDistribution: TextLeadingDistribution.even,
                              color: AppColors.talkStopRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Session body: header (top) → spacer → avatar stage (bottom-pinned).
class _FigmaSessionColumn extends StatelessWidget {
  const _FigmaSessionColumn({required this.header, required this.stage});

  final Widget header;
  final Widget Function(double height) stage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stageHeight = math.min(
                AppSpacing.talkSessionAvatarCardHeight,
                constraints.maxHeight,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const Spacer(), stage(stageHeight)],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PartialTranscriptHeader extends StatelessWidget {
  const _PartialTranscriptHeader({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.talkSessionStatusBottom,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: double.infinity,
          child: _TranscriptBubble(transcript: transcript),
        ),
      ),
    );
  }
}

class _FullTranscriptHeader extends StatelessWidget {
  const _FullTranscriptHeader({
    required this.transcript,
    required this.metaLabel,
  });

  final String transcript;
  final String metaLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.talkSessionStatusBottom,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SigningTranscriptBubble(transcript: transcript),
              const SizedBox(height: AppSpacing.talkSessionMetaTop),
              _HeardMetaRow(label: metaLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared avatar card used by Listening, Heard, and Signing.
class _TalkAvatarCardStage extends StatelessWidget {
  const _TalkAvatarCardStage({
    required this.height,
    required this.fallbackAsset,
    required this.signTokenId,
    required this.signSystem,
    required this.signingWord,
    required this.signPulse,
    required this.signingChip,
  });

  final double height;
  final String fallbackAsset;
  final String signTokenId;
  final SignLanguageSystem signSystem;
  final String signingWord;
  final int signPulse;
  final Widget signingChip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
          bottom: AppSpacing.talkSessionAvatarCardPaddingBottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.talkScreenBackground,
          border: Border.all(
            color: AppColors.talkAvatarCardBorder,
            width: 0.52,
          ),
          borderRadius: BorderRadius.circular(
            AppSpacing.talkSessionAvatarCardRadius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: signingChip,
              ),
            ),
            const SizedBox(height: AppSpacing.talkSessionSigningChipToAvatarGap),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: AppSpacing.talkSessionAvatarIlluWidth,
                  height: AppSpacing.talkSessionAvatarIlluHeight,
                  child: SignAvatarView(
                    signTokenId: signTokenId,
                    signSystem: signSystem,
                    fallbackAsset: fallbackAsset,
                    signingWord: signingWord,
                    signPulse: signPulse,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalkBubbleContainer extends StatelessWidget {
  const _TalkBubbleContainer({required this.borderColor, required this.child});

  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.talkSessionBubblePaddingH,
        AppSpacing.talkSessionBubblePaddingTop,
        AppSpacing.talkSessionBubblePaddingH,
        AppSpacing.talkSessionBubblePaddingBottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: borderColor, width: 1.04),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.talkSessionBubbleRadiusSmall),
          topRight: Radius.circular(AppSpacing.talkSessionBubbleRadiusLarge),
          bottomRight: Radius.circular(AppSpacing.talkSessionBubbleRadiusLarge),
          bottomLeft: Radius.circular(AppSpacing.talkSessionBubbleRadiusLarge),
        ),
      ),
      child: child,
    );
  }
}

TextStyle get _transcriptTextStyle => const TextStyle(
  fontFamily: 'Klavika',
  fontWeight: FontWeight.w400,
  fontSize: AppSpacing.talkSessionTranscriptFont,
  height: AppSpacing.talkSessionTranscriptLineHeight,
  leadingDistribution: TextLeadingDistribution.even,
  color: AppColors.talkBubbleText,
);

class _SigningTranscriptBubble extends StatelessWidget {
  const _SigningTranscriptBubble({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return _TalkBubbleContainer(
      borderColor: AppColors.talkHeardBubbleBorder,
      child: _CaptionBubbleBody(
        transcript: transcript,
        maxHeight: AppSpacing.talkSessionCaptionMaxHeight,
      ),
    );
  }
}

class _HeardMetaRow extends StatelessWidget {
  const _HeardMetaRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.talkSessionMetaPaddingLeft,
        top: AppSpacing.talkSessionMetaPaddingTop,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.talkSessionMetaDotSize,
            height: AppSpacing.talkSessionMetaDotSize,
            decoration: const BoxDecoration(
              color: AppColors.splashBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.talkSessionMetaDotGap),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Klavika',
              fontWeight: FontWeight.w400,
              fontSize: 10,
              height: 1.5,
              leadingDistribution: TextLeadingDistribution.even,
              color: AppColors.talkMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStatusBubble extends StatelessWidget {
  const _SessionStatusBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _TalkBubbleContainer(
      borderColor: AppColors.splashBlue,
      child: Text(
        label,
        style: _transcriptTextStyle.copyWith(color: AppColors.talkMutedText),
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return _TalkBubbleContainer(
      borderColor: AppColors.splashBlue,
      child: _CaptionBubbleBody(
        transcript: transcript,
        maxHeight: AppSpacing.talkSessionCaptionMaxHeight,
        trailing: Container(
          width: AppSpacing.talkSessionCursorWidth,
          height: AppSpacing.talkSessionCursorHeight,
          color: AppColors.splashBlue.withValues(alpha: 0.71),
        ),
      ),
    );
  }
}

class _CaptionBubbleBody extends StatelessWidget {
  const _CaptionBubbleBody({
    required this.transcript,
    required this.maxHeight,
    this.trailing,
  });

  final String transcript;
  final double maxHeight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _ScrollableTranscriptText(
      transcript: transcript,
      maxHeight: maxHeight,
      trailing: trailing,
    );
  }
}

class _ScrollableTranscriptText extends StatefulWidget {
  const _ScrollableTranscriptText({
    required this.transcript,
    required this.maxHeight,
    this.trailing,
  });

  final String transcript;
  final double maxHeight;
  final Widget? trailing;

  @override
  State<_ScrollableTranscriptText> createState() =>
      _ScrollableTranscriptTextState();
}

class _ScrollableTranscriptTextState extends State<_ScrollableTranscriptText> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ScrollableTranscriptText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transcript != widget.transcript) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    void scrollOnce() {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (target <= 0) {
        return;
      }
      try {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Ignore transient scroll attach/detach during rapid rebuilds.
      }
    }

    // Run after layout, and once again shortly after to catch fast-growing text.
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollOnce());
    Future<void>.delayed(const Duration(milliseconds: 40), scrollOnce);
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.transcript,
      style: _transcriptTextStyle,
      softWrap: true,
    );

    final body = widget.trailing == null
        ? text
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: text),
              const SizedBox(width: AppSpacing.talkSessionCursorGap),
              widget.trailing!,
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: body,
      ),
    );
  }
}

class _OverlaySigningChip extends StatelessWidget {
  const _OverlaySigningChip({
    required this.prefix,
    required this.word,
    this.systemLabel,
  });

  final String prefix;
  final String? word;
  final String? systemLabel;

  @override
  Widget build(BuildContext context) {
    final word = this.word?.trim() ?? '';
    if (word.isEmpty) {
      return const SizedBox.shrink();
    }
    final systemSuffix = systemLabel == null ? '' : ' · $systemLabel';
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChipWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width -
                (AppSpacing.screenPaddingH * 2);

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxChipWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.talkSigningChipBg,
              border: Border.all(
                color: AppColors.talkSigningChipBorder,
                width: 0.52,
              ),
              borderRadius: BorderRadius.circular(100),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: AppSpacing.talkSessionSigningChipMaxHeight,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$prefix ',
                        style: const TextStyle(
                          fontFamily: 'Klavika',
                          fontWeight: FontWeight.w400,
                          fontSize: AppSpacing.talkSessionSigningChipFont,
                          height: 16 / 12,
                          leadingDistribution: TextLeadingDistribution.even,
                          color: AppColors.splashBlue,
                        ),
                      ),
                      TextSpan(
                        text: '$word$systemSuffix',
                        style: const TextStyle(
                          fontFamily: 'Klavika',
                          fontWeight: FontWeight.w700,
                          fontSize: AppSpacing.talkSessionSigningChipFont,
                          height: 16 / 12,
                          leadingDistribution: TextLeadingDistribution.even,
                          color: AppColors.splashBlue,
                        ),
                      ),
                    ],
                  ),
                  softWrap: true,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Status bubble reused by the sign-capture flow (e.g. "Recording signs…").
class TalkSessionStatusBubble extends StatelessWidget {
  const TalkSessionStatusBubble({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => _SessionStatusBubble(label: label);
}

/// Transcript + meta row reused by heard/spoken conversation headers.
class TalkFullTranscriptHeader extends StatelessWidget {
  const TalkFullTranscriptHeader({
    super.key,
    required this.transcript,
    required this.metaLabel,
  });

  final String transcript;
  final String metaLabel;

  @override
  Widget build(BuildContext context) {
    return _FullTranscriptHeader(transcript: transcript, metaLabel: metaLabel);
  }
}
