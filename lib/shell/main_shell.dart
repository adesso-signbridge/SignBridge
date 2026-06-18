import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/di/service_locator.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/language_change_coordinator.dart';
import '../features/home/presentation/settings_drawer.dart';
import '../features/phrases/presentation/phrases_screen.dart';
import '../services/home/home_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _phrasesTabMounted = false;
  String _appVersion = '1.0.0';
  String _languageCode = 'ENG';
  HomeContent? _homeContent;
  bool _emergencyActive = false;
  AppSessionMode _homeSessionMode = AppSessionMode.idle;
  HomeSessionRegistration? _homeSession;
  late final HomeService _homeService = ServiceLocator.instance.home;

  HomeUiCopy get _uiCopy => _homeService.uiCopyFor(_languageCode);

  @override
  void initState() {
    super.initState();
    _homeService.fetchHomeContent().then((content) {
      if (mounted) {
        setState(() {
          _appVersion = content.appVersion;
          _languageCode = content.selectedLanguageCode;
          _homeContent = content;
        });
      }
    });
  }

  void _registerHomeSession(HomeSessionRegistration registration) {
    _homeSession = registration;
  }

  void _unregisterHomeSession() {
    _homeSession = null;
    _homeSessionMode = AppSessionMode.idle;
  }

  void _onHomeSessionModeChanged(AppSessionMode mode) {
    _homeSessionMode = mode;
  }

  Future<void> _requestLanguageChange(String newCode) async {
    if (newCode == _languageCode) {
      return;
    }

    final uiCopy = _uiCopy;
    final mode = _emergencyActive
        ? AppSessionMode.emergencyActive
        : _homeSessionMode;
    final action = LanguageChangeCoordinator.actionFor(mode);

    switch (action) {
      case LanguageChangeAction.block:
        _showSnackBar(LanguageChangeCoordinator.blockMessageFor(mode, uiCopy));
        return;
      case LanguageChangeAction.confirmThenTeardown:
        final confirmed = await _showLanguageChangeConfirmDialog(
          title: uiCopy.languageChangeConfirmTitle,
          body: LanguageChangeCoordinator.confirmBodyFor(mode, uiCopy),
          cancelLabel: uiCopy.emergencyCancelLabel,
          confirmLabel: uiCopy.languageChangeConfirmLabel,
        );
        if (!confirmed || !mounted) {
          return;
        }
        await _homeSession?.teardownActiveSessions();
        break;
      case LanguageChangeAction.applyImmediate:
        break;
    }

    if (!mounted) {
      return;
    }

    await ServiceLocator.instance.phraseSpeech.stop();
    setState(() => _languageCode = newCode);

    final languageLabel = _languageLabelFor(newCode);
    final snackCopy = _homeService.uiCopyFor(newCode);
    _showSnackBar(snackCopy.languageChangedSnackbarFor(languageLabel));
  }

  String _languageLabelFor(String code) {
    final languages = _homeContent?.languages;
    if (languages == null) {
      return code;
    }
    return languages
        .firstWhere(
          (language) => language.code == code,
          orElse: () => languages.first,
        )
        .label;
  }

  Future<bool> _showLanguageChangeConfirmDialog({
    required String title,
    required String body,
    required String cancelLabel,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceLocator.instance;
    final uiCopy = _uiCopy;
    final tabs = [
      _TabItem(icon: Icons.chat_bubble_outline, label: uiCopy.talkTabLabel),
      _TabItem(
        asset: 'assets/home/tabs/tab_book.png',
        label: uiCopy.phrasesTabLabel,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.white,
        endDrawerEnableOpenDragGesture: true,
        endDrawer: SettingsDrawer(
          appVersion: _appVersion,
          uiCopy: uiCopy,
          languageCode: _languageCode,
          sosService: services.sos,
          onEmergencyActiveChanged: (active) {
            if (_emergencyActive != active) {
              setState(() => _emergencyActive = active);
            }
          },
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              homeService: _homeService,
              translateService: services.translate,
              signCaptureService: services.signCapture,
              phraseSpeechService: services.phraseSpeech,
              glossService: services.gloss,
              selectedLanguageCode: _languageCode,
              uiCopy: uiCopy,
              emergencyActive: _emergencyActive,
              onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              onLanguageChanged: (code) => unawaited(_requestLanguageChange(code)),
              onRegisterSession: _registerHomeSession,
              onUnregisterSession: _unregisterHomeSession,
              onSessionModeChanged: _onHomeSessionModeChanged,
            ),
            if (_phrasesTabMounted)
              PhrasesScreen(
                homeService: _homeService,
                phrasesService: services.phrases,
                speechService: services.phraseSpeech,
                languageCode: _languageCode,
                onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                onLanguageChanged: (code) => unawaited(_requestLanguageChange(code)),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _AppTabBar(
          selectedIndex: _selectedIndex,
          tabs: tabs,
          onSelected: (index) => setState(() {
            if (index == 1) {
              _phrasesTabMounted = true;
            }
            _selectedIndex = index;
          }),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, this.asset, this.icon})
    : assert(asset != null || icon != null);

  final String label;
  final String? asset;
  final IconData? icon;
}

class _AppTabBar extends StatelessWidget {
  const _AppTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.phraseBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++) ...[
                if (index > 0)
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.phraseBorder,
                  ),
                Expanded(
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TabIcon(
                          tab: tabs[index],
                          selected: index == selectedIndex,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[index].label,
                          style: TextStyle(
                            fontSize: AppTypography.tabLabel,
                            fontWeight: index == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: index == selectedIndex
                                ? AppColors.splashBlue
                                : AppColors.tabInactive,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.tab, required this.selected});

  final _TabItem tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.splashBlue : AppColors.tabInactive;

    if (tab.icon != null) {
      return Icon(tab.icon, size: AppTypography.tabIcon, color: color);
    }

    final image = Image.asset(
      tab.asset!,
      width: AppTypography.tabIcon,
      height: AppTypography.tabIcon,
      fit: BoxFit.contain,
    );

    if (!selected) {
      return image;
    }

    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: image,
    );
  }
}
