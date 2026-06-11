import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/home/home_service.dart';
import '../../../services/phrases/phrase_catalog.dart';
import '../../../services/phrases/phrases_service.dart';
import '../../shared/presentation/sign_bridge_header.dart';

class PhrasesScreen extends StatefulWidget {
  const PhrasesScreen({
    super.key,
    required this.homeService,
    required this.phrasesService,
    required this.speechService,
    required this.languageCode,
    required this.onMenuTap,
    required this.onLanguageChanged,
  });

  final HomeService homeService;
  final PhrasesService phrasesService;
  final PhraseSpeechService speechService;
  final String languageCode;
  final VoidCallback onMenuTap;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends State<PhrasesScreen> {
  HomeContent? _content;
  bool _languageMenuOpen = false;
  String _selectedCategoryId = PhraseCatalog.allCategoryId;
  String _searchQuery = '';
  String? _speakingPhraseId;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  PhrasesUiCopy get _uiCopy =>
      widget.phrasesService.uiCopyFor(widget.languageCode);

  @override
  void initState() {
    super.initState();
    widget.homeService.fetchHomeContent().then((content) {
      if (mounted) {
        setState(() => _content = content);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  HomeLanguage? get _selectedLanguage {
    final content = _content;
    if (content == null) {
      return null;
    }
    return content.languages.firstWhere(
      (language) => language.code == widget.languageCode,
      orElse: () => content.languages.first,
    );
  }

  List<PhraseItem> get _visiblePhrases {
    return widget.phrasesService.phrases(
      categoryId: _selectedCategoryId,
      searchQuery: _searchQuery,
    );
  }

  Future<void> _onPhraseTap(PhraseItem phrase) async {
    await widget.speechService.stop();
    setState(() => _speakingPhraseId = phrase.id);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await widget.speechService.speak(phrase.text, widget.languageCode);
    } finally {
      if (mounted) {
        setState(() => _speakingPhraseId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) {
      return const ColoredBox(
        color: AppColors.talkScreenBackground,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final categories = <({String id, String label})>[
      (id: PhraseCatalog.allCategoryId, label: _uiCopy.allLabel),
      for (final category in widget.phrasesService.categories())
        (id: category.id, label: _uiCopy.categoryLabel(category.id)),
    ];

    return ColoredBox(
      color: AppColors.talkScreenBackground,
      child: SafeArea(
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
                ColoredBox(
                  color: AppColors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingH,
                      AppSpacing.screenPaddingTop,
                      AppSpacing.screenPaddingH,
                      AppSpacing.headerPaddingBottom,
                    ),
                    child: SignBridgeHeader(
                      selectedLanguage: _selectedLanguage,
                      languageMenuOpen: _languageMenuOpen,
                      onLanguageTap: () => setState(
                        () => _languageMenuOpen = !_languageMenuOpen,
                      ),
                      onMenuTap: widget.onMenuTap,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: _PhraseSearchField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          hint: _uiCopy.searchHint,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final chip = categories[index];
                            final selected = chip.id == _selectedCategoryId;
                            return Align(
                              alignment: Alignment.center,
                              child: _CategoryChip(
                                label: chip.label,
                                selected: selected,
                                onTap: () => setState(
                                  () => _selectedCategoryId = chip.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          itemCount: _visiblePhrases.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final phrase = _visiblePhrases[index];
                            final isSpeaking = _speakingPhraseId == phrase.id;
                            return _PhraseTile(
                              phrase: phrase,
                              categoryLabel: _uiCopy.categoryLabel(
                                phrase.category.id,
                              ),
                              selected: isSpeaking,
                              onTap: () => _onPhraseTap(phrase),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_languageMenuOpen)
              Positioned(
                top: 72,
                right: AppSpacing.screenPaddingH,
                child: SignBridgeLanguageMenu(
                  languages: content.languages,
                  selectedCode: widget.languageCode,
                  onSelected: (code) {
                    setState(() => _languageMenuOpen = false);
                    widget.onLanguageChanged(code);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhraseSearchField extends StatelessWidget {
  const _PhraseSearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.phraseCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: AppColors.tabInactive),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: const TextStyle(
                  fontFamily: 'Klavika',
                  fontSize: 14,
                  height: 17 / 14,
                  color: AppColors.talkBubbleText,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontFamily: 'Klavika',
                    fontSize: 14,
                    height: 17 / 14,
                    color: AppColors.talkBubbleText.withValues(alpha: 0.5),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.splashBlue : AppColors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.splashBlue
                  : AppColors.phraseChipBorder,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: 'Klavika',
              fontSize: AppTypography.phraseChip,
              height: AppTypography.phraseChipLineHeight,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.phraseCategoryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({
    required this.phrase,
    required this.categoryLabel,
    required this.selected,
    required this.onTap,
  });

  final PhraseItem phrase;
  final String categoryLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.phraseSelectedBackground : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.splashBlue
                  : AppColors.phraseCardBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phrase.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Klavika',
                        fontWeight: FontWeight.w700,
                        fontSize: AppTypography.phraseCardTitle,
                        height: 1.35,
                        color: AppColors.talkBubbleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Klavika',
                        fontWeight: FontWeight.w700,
                        fontSize: AppTypography.phraseCardCategory,
                        height: 1.2,
                        color: AppColors.phraseCategoryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.splashBlue
                      : AppColors.phraseSpeakerIdle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: selected ? AppColors.white : AppColors.splashBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
