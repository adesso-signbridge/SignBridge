import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/home/home_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.homeService,
    required this.onMenuTap,
  });

  final HomeService homeService;
  final VoidCallback onMenuTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeContent? _content;
  String? _selectedLanguageCode;
  bool _languageMenuOpen = false;

  @override
  void initState() {
    super.initState();
    widget.homeService.fetchHomeContent().then((content) {
      if (mounted) {
        setState(() {
          _content = content;
          _selectedLanguageCode = content.selectedLanguageCode;
        });
      }
    });
  }

  HomeLanguage? get _selectedLanguage {
    final content = _content;
    if (content == null || _selectedLanguageCode == null) {
      return null;
    }
    return content.languages.firstWhere(
      (language) => language.code == _selectedLanguageCode,
      orElse: () => content.languages.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          if (_languageMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _languageMenuOpen = false),
                child: Container(color: Colors.transparent),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  AppSpacing.screenPaddingTop,
                  AppSpacing.screenPaddingH,
                  0,
                ),
                child: _HomeHeader(
                  selectedLanguage: _selectedLanguage,
                  languageMenuOpen: _languageMenuOpen,
                  onLanguageTap: () =>
                      setState(() => _languageMenuOpen = !_languageMenuOpen),
                  onMenuTap: widget.onMenuTap,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.talkContentPaddingH,
                    AppSpacing.talkContentPaddingTop,
                    AppSpacing.talkContentPaddingH,
                    AppSpacing.talkContentPaddingBottom,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: AppTypography.talkEmptyTextWidth,
                            child: Text(
                              content.emptyStateMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Klavika',
                                fontWeight: FontWeight.w400,
                                fontSize: AppTypography.talkEmptyText,
                                height: AppTypography.talkEmptyLineHeight,
                                color: AppColors.talkMutedText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.talkContentInnerPaddingBottom,
                        ),
                        child: const _TalkActionButtons(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_languageMenuOpen)
            Positioned(
              top: 72,
              right: AppSpacing.talkContentPaddingH,
              child: _LanguageMenu(
                languages: content.languages,
                selectedCode: _selectedLanguageCode!,
                onSelected: (code) => setState(() {
                  _selectedLanguageCode = code;
                  _languageMenuOpen = false;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.selectedLanguage,
    required this.languageMenuOpen,
    required this.onLanguageTap,
    required this.onMenuTap,
  });

  final HomeLanguage? selectedLanguage;
  final bool languageMenuOpen;
  final VoidCallback onLanguageTap;
  final VoidCallback onMenuTap;

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
        GestureDetector(
          onTap: onLanguageTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.langPillPaddingH,
              vertical: AppSpacing.langPillPaddingV,
            ),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(AppSpacing.langPillRadius),
              border: languageMenuOpen
                  ? Border.all(color: AppColors.splashBlue, width: 1)
                  : null,
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
                  selectedLanguage?.code ?? 'ENG',
                  style: const TextStyle(
                    fontSize: AppTypography.langText,
                    fontWeight: FontWeight.w600,
                    color: AppColors.splashBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.langTextToChevron),
                Icon(
                  languageMenuOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: AppTypography.langGlobe,
                  color: AppColors.splashBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.headerMenuGap),
        GestureDetector(
          key: const Key('home_menu_button'),
          onTap: onMenuTap,
          child: Image.asset(
            'assets/home/icon_menu.png',
            width: AppTypography.menuIconW,
            height: AppTypography.menuIconH,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.languages,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<HomeLanguage> languages;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.white,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.phraseBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in languages)
              InkWell(
                onTap: () => onSelected(language.code),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: language.code == selectedCode
                      ? AppColors.lightBlue
                      : Colors.transparent,
                  child: Text(
                    language.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: language.code == selectedCode
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: language.code == selectedCode
                          ? AppColors.splashBlue
                          : AppColors.textPrimary,
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

class _TalkActionButtons extends StatelessWidget {
  const _TalkActionButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _TalkActionButton(
          asset: 'assets/home/btn_listen.png',
          label: 'Tap to listen',
        ),
        SizedBox(width: AppSpacing.talkButtonGap),
        _TalkActionButton(
          asset: 'assets/home/btn_sign.png',
          label: 'Tap to sign',
        ),
      ],
    );
  }
}

class _TalkActionButton extends StatelessWidget {
  const _TalkActionButton({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppTypography.talkButtonSize,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {},
            child: Image.asset(
              asset,
              width: AppTypography.talkButtonSize,
              height: AppTypography.talkButtonSize,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppSpacing.talkButtonToLabel),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Klavika',
              fontWeight: FontWeight.w400,
              fontSize: AppTypography.talkButtonLabel,
              height: AppTypography.talkButtonLabelLineHeight,
              color: AppColors.talkMutedText,
            ),
          ),
        ],
      ),
    );
  }
}
