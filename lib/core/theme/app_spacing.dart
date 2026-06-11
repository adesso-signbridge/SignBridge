/// Figma Container.pdf layout spacing (375pt frame).
abstract final class AppSpacing {
  static const double screenPaddingH = 20;
  static const double screenPaddingTop = 20;
  static const double screenPaddingBottom = 24;

  static const double headerLogoGap = 12;
  static const double headerMenuGap = 12;
  static const double headerPaddingBottom = 16;

  static const double headerToCards = 20;
  static const double cardGap = 13;
  static const double cardsToQuickPhrases = 17;
  static const double quickPhrasesToTiles = 14;
  static const double phraseTileGap = 8;
  static const double phrasesToFooter = 60;

  static const double cardPaddingTop = 20;
  static const double cardIconToTitle = 10;
  static const double cardTitleToSubtitle = 3;
  static const double cardPaddingBottom = 24;
  static const double cardRadius = 16;

  static const double langPillPaddingH = 12;
  static const double langPillPaddingV = 6;
  static const double langPillRadius = 20;
  static const double langGlobeToText = 6;
  static const double langTextToChevron = 4;

  static const double phraseTilePaddingH = 14;
  static const double phraseTilePaddingV = 12;
  static const double phraseTileHeight = 46;
  static const double phraseTileRadius = 16;
  static const double phraseIconGap = 12;

  // Figma Talk container (375pt frame).
  static const double talkContentPaddingTop = 12;
  static const double talkContentPaddingH = 16;
  static const double talkContentPaddingBottom = 8;
  static const double talkContentInnerWidth = 343;
  static const double talkEmptyToButtons = 12;
  static const double talkContentInnerPaddingBottom = 16;
  static const double talkButtonGap = 77;
  static const double talkButtonGapMin = 24;
  static const double talkButtonToLabel = 3;
  static const double talkButtonLabelHeight = 20;
  static const double talkButtonsRowWidth =
      213; // 68 + 77 + 68 (Figma 212.99px)

  // Figma Listening / Heard / Signing session (375pt frame, 466px body).
  static const double talkSessionStatusBottom = 12;
  static const double talkSessionBubblePaddingH = 16;
  static const double talkSessionBubblePaddingTop = 12;
  static const double talkSessionBubblePaddingBottom = 12;
  static const double talkSessionBubbleRadiusSmall = 8;
  static const double talkSessionBubbleRadiusLarge = 16;
  static const double talkSessionAvatarCardRadius = 16;
  static const double talkSessionAvatarCardPaddingBottom = 24;

  // Figma overlay clearance inside the avatar card (Heard: dots top ~46px).
  static const double talkSessionAvatarIlluTopInset = 48;
  static const double talkSessionSigningChipTopInCard = -8;
  static const double talkSessionThinkingDotsTopInCard = 14;
  static const double talkSessionThinkingDotsRightInCard = 42;

  static const double talkSessionAvatarCardMinHeight = 220;

  // Avatar card + illustration — all session states share one fixed card size.
  static const double talkSessionAvatarCardHeight = 260;
  static const double talkSessionListeningAvatarCardHeight =
      talkSessionAvatarCardHeight;
  static const double talkSessionAvatarIlluWidth = 237;
  static const double talkSessionAvatarIlluHeight = 235;

  /// Illustration slot below the overlay headroom inside the avatar card.
  static const double talkSessionAvatarIlluSlotHeight = 188;
  static const double talkSessionListeningIlluWidth =
      talkSessionAvatarIlluWidth;
  static const double talkSessionListeningIlluHeight =
      talkSessionAvatarIlluHeight;

  static const double talkSessionStoppedControlsGap = 13;
  static const double talkSessionClearHistoryRowHeight = 30;
  static const double talkSessionClearHistoryWidth = 100;
  static const double talkSessionClearHistoryHeight = 24;
  static const double talkSessionClearHistoryPaddingV = 6;
  static const double talkSessionClearHistoryGap = 4;
  static const double talkSessionClearHistoryIconSize = 12;
  static const double talkSessionClearHistoryBorderWidth = 1;
  static const double talkSessionClearHistoryRadius = 12;
  static const double talkSessionClearHistoryFontSize = 12;
  static const double talkSessionClearHistoryLineHeight = 18;

  static const double talkSessionMetaTop = 8;
  static const double talkSessionMetaPaddingTop = 4;
  static const double talkSessionMetaPaddingLeft = 4;
  static const double talkSessionMetaDotGap = 6;
  static const double talkSessionMetaDotSize = 6;

  static const double talkSessionWaveformPaddingV = 4;
  static const double talkSessionWaveformToButtons = 3;
  static const double talkSessionWaveformHeight = 40;
  static const double talkSessionWaveformBarWidth = 3;
  static const double talkSessionWaveformGap = 2;
  static const int talkSessionWaveformBarCount = 16;

  static const double talkSessionThinkingDotSize = 7;
  static const double talkSessionThinkingDotGap = 6;

  static const double talkSessionStopRing = 8;
  static const double talkSessionSignMutedOpacity = 0.4;
  static const double talkSessionSigningChipFont = 12;
  static const double talkSessionTranscriptFont = 14;
  static const double talkSessionTranscriptLineHeight = 21 / 14;
  static const double talkSessionLiveTranscriptMaxHeight = 105;
  static const double talkSessionFullTranscriptMaxHeight = 168;
  static const double talkSessionCursorWidth = 2;
  static const double talkSessionCursorGap = 4;
  static const double talkSessionCursorHeight = 16;
}
