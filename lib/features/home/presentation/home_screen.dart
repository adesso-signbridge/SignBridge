import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/home/home_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.homeService});

  final HomeService homeService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeContent>(
      future: homeService.fetchHomeContent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final content = snapshot.data!;
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              AppSpacing.screenPaddingTop,
              AppSpacing.screenPaddingH,
              AppSpacing.screenPaddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HomeHeader(language: content.selectedLanguage),
                const SizedBox(height: AppSpacing.headerToCards),
                _ActionCardsRow(cards: content.actionCards),
                const SizedBox(height: AppSpacing.cardsToQuickPhrases),
                const _QuickPhrasesHeader(),
                const SizedBox(height: AppSpacing.quickPhrasesToTiles),
                ...content.quickPhrases.map(
                  (phrase) => _PhraseTile(text: phrase),
                ),
                const SizedBox(height: AppSpacing.phrasesToFooter),
                const _AdessoFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/home/app_logo.png',
          width: AppTypography.headerLogo,
          height: AppTypography.headerLogo,
        ),
        const SizedBox(width: AppSpacing.headerLogoGap),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SignBridge',
                style: TextStyle(
                  fontFamily: 'Klavika',
                  fontWeight: FontWeight.w700,
                  fontSize: AppTypography.headerTitle,
                  height: 1.2,
                  color: AppColors.splashBlue,
                ),
              ),
              Text(
                'by adesso',
                style: TextStyle(
                  fontSize: AppTypography.headerSubtitle,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _LanguageSelector(language: language),
        const SizedBox(width: AppSpacing.headerMenuGap),
        Image.asset(
          'assets/home/icon_menu.png',
          width: AppTypography.menuIconW,
          height: AppTypography.menuIconH,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.langPillPaddingH,
        vertical: AppSpacing.langPillPaddingV,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(AppSpacing.langPillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/home/icon_globe.png',
            width: AppTypography.langGlobe,
            height: AppTypography.langGlobe,
          ),
          const SizedBox(width: AppSpacing.langGlobeToText),
          Text(
            language,
            style: const TextStyle(
              fontSize: AppTypography.langText,
              fontWeight: FontWeight.w600,
              color: AppColors.splashBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.langTextToChevron),
          const Icon(
            Icons.keyboard_arrow_down,
            size: AppTypography.langGlobe,
            color: AppColors.splashBlue,
          ),
        ],
      ),
    );
  }
}

class _ActionCardsRow extends StatelessWidget {
  const _ActionCardsRow({required this.cards});

  final List<HomeActionCard> cards;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.cardGap),
            Expanded(child: _ActionCard(card: cards[i])),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.card});

  final HomeActionCard card;

  IconData get _icon => switch (card.mode) {
    HomeActionMode.hearForMe => Icons.hearing,
    HomeActionMode.speakForMe => Icons.pan_tool_alt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        14,
        AppSpacing.cardPaddingTop,
        14,
        AppSpacing.cardPaddingBottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.splashBlue,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: AppTypography.cardIconBox,
            height: AppTypography.cardIconBox,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _icon,
              color: AppColors.white,
              size: AppTypography.cardIcon,
            ),
          ),
          const SizedBox(height: AppSpacing.cardIconToTitle),
          Text(
            card.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTypography.cardTitle,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.cardTitleToSubtitle),
          Text(
            card.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.cardSubtitle,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.9),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPhrasesHeader extends StatelessWidget {
  const _QuickPhrasesHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Quick Phrases',
            style: TextStyle(
              fontSize: AppTypography.sectionLabel,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          'See all',
          style: TextStyle(
            fontSize: AppTypography.sectionLink,
            fontWeight: FontWeight.w700,
            color: AppColors.splashBlue,
          ),
        ),
      ],
    );
  }
}

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.phraseTileHeight,
      margin: const EdgeInsets.only(bottom: AppSpacing.phraseTileGap),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.phraseTilePaddingH,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.phraseTileRadius),
        border: Border.all(color: AppColors.phraseBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.bolt,
            color: AppColors.splashBlue,
            size: AppTypography.phraseBolt,
          ),
          const SizedBox(width: AppSpacing.phraseIconGap),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: AppTypography.phraseText,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdessoFooter extends StatelessWidget {
  const _AdessoFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/home/adesso_footer.png',
        width: AppTypography.adessoFooterW,
        height: AppTypography.adessoFooterH,
        fit: BoxFit.contain,
      ),
    );
  }
}
