import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/di/service_locator.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/settings_drawer.dart';
import '../features/shared/presentation/microservice_tab_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String _appVersion = '1.0.0';

  static const _tabs = [
    _TabItem(icon: Icons.chat_bubble_outline, label: 'Talk'),
    _TabItem(asset: 'assets/home/tabs/tab_book.png', label: 'Phrases'),
  ];

  @override
  void initState() {
    super.initState();
    ServiceLocator.instance.home.fetchHomeContent().then((content) {
      if (mounted) {
        setState(() => _appVersion = content.appVersion);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceLocator.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.white,
        endDrawerEnableOpenDragGesture: true,
        endDrawer: SettingsDrawer(appVersion: _appVersion),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              homeService: services.home,
              onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
            MicroserviceTabScreen(
              serviceName: services.phrases.serviceName,
              titleFuture: services.phrases.getStatusMessage(),
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
