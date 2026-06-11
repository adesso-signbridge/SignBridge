import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/home/home_service.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({
    super.key,
    required this.appVersion,
    required this.uiCopy,
  });

  final String appVersion;
  final HomeUiCopy uiCopy;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.85,
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      uiCopy.settingsTitle,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const _DrawerCloseButton(),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(uiCopy.emergencySection),
                    const SizedBox(height: 12),
                    _SettingsButton(
                      label: uiCopy.callEmergency,
                      icon: Icons.phone,
                      backgroundColor: AppColors.splashBlue,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _SettingsButton(
                      label: uiCopy.sos,
                      backgroundColor: AppColors.emergencyRed,
                      onTap: () {},
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel(uiCopy.aboutSection),
                    const SizedBox(height: 8),
                    _AboutRow(label: uiCopy.appLabel, value: 'SignBridge'),
                    const Divider(color: AppColors.phraseBorder, height: 1),
                    _AboutRow(label: uiCopy.versionLabel, value: appVersion),
                    const SizedBox(height: 48),
                    Center(
                      child: Image.asset(
                        'assets/home/adesso_footer.png',
                        width: AppTypography.adessoFooterW,
                        height: AppTypography.adessoFooterH,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        uiCopy.footerCopyright,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCloseButton extends StatelessWidget {
  const _DrawerCloseButton();

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.splashBlue,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: _size,
          height: _size,
          child: Icon(
            Icons.close,
            size: 20,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.label,
    required this.backgroundColor,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: icon != null ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
