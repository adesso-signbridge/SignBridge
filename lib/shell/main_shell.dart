import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/di/service_locator.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/shared/presentation/microservice_tab_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    _TabItem(asset: 'assets/home/tabs/tab_home.png', label: 'Home'),
    _TabItem(asset: 'assets/home/tabs/tab_convert.png', label: 'Translate'),
    _TabItem(asset: 'assets/home/tabs/tab_book.png', label: 'Phrases'),
    _TabItem(asset: 'assets/home/tabs/tab_alert.png', label: 'SOS'),
    _TabItem(asset: 'assets/home/tabs/tab_settings.png', label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final services = ServiceLocator.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(homeService: services.home),
            MicroserviceTabScreen(
              serviceName: services.translate.serviceName,
              titleFuture: services.translate.getStatusMessage(),
            ),
            MicroserviceTabScreen(
              serviceName: services.phrases.serviceName,
              titleFuture: services.phrases.getStatusMessage(),
            ),
            MicroserviceTabScreen(
              serviceName: services.sos.serviceName,
              titleFuture: services.sos.getStatusMessage(),
            ),
            MicroserviceTabScreen(
              serviceName: services.settings.serviceName,
              titleFuture: services.settings.getStatusMessage(),
            ),
          ],
        ),
        bottomNavigationBar: _AppTabBar(
          selectedIndex: _selectedIndex,
          tabs: _tabs,
          onSelected: (index) => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.asset, required this.label});

  final String asset;
  final String label;
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
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final selected = index == selectedIndex;
            final tab = tabs[index];
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TabIcon(asset: tab.asset, selected: selected),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: AppTypography.tabLabel,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? AppColors.splashBlue
                              : AppColors.tabInactive,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.asset, required this.selected});

  final String asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: AppTypography.tabIcon,
      height: AppTypography.tabIcon,
      fit: BoxFit.contain,
    );

    final color = selected ? AppColors.splashBlue : AppColors.tabInactive;

    if (asset.endsWith('tab_home.png') && selected) {
      return image;
    }
    if (!selected && !asset.endsWith('tab_home.png')) {
      return image;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: image,
    );
  }
}
