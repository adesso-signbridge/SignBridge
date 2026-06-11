import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Visible signing feedback layered on the avatar illustration.
class AslSignOverlay extends StatefulWidget {
  const AslSignOverlay({
    super.key,
    required this.signTokenId,
    required this.gloss,
    this.pulse = 0,
  });

  final String signTokenId;
  final String gloss;
  final int pulse;

  @override
  State<AslSignOverlay> createState() => _AslSignOverlayState();
}

class _AslSignOverlayState extends State<AslSignOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant AslSignOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signTokenId != widget.signTokenId ||
        oldWidget.pulse != widget.pulse) {
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _SignMotion.forToken(widget.signTokenId);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: 28,
              top: 72 + motion.offsetDy * (1 - t),
              child: Transform.rotate(
                angle: motion.rotation * t,
                child: Transform.scale(
                  scale: 0.85 + t * 0.25,
                  child: _HandBadge(icon: motion.icon, gloss: widget.gloss),
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 36,
              child: Opacity(
                opacity: t * 0.85,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.splashBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    motion.label,
                    style: const TextStyle(
                      fontFamily: 'Klavika',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.splashBlue,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HandBadge extends StatelessWidget {
  const _HandBadge({required this.icon, required this.gloss});

  final IconData icon;
  final String gloss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.splashBlue, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.splashBlue.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.splashBlue, size: 28),
          if (gloss.isNotEmpty && gloss != '...')
            Text(
              gloss.length > 6 ? gloss.substring(0, 6) : gloss,
              style: const TextStyle(
                fontFamily: 'Klavika',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.splashBlue,
              ),
            ),
        ],
      ),
    );
  }
}

class _SignMotion {
  const _SignMotion({
    required this.icon,
    required this.label,
    this.rotation = 0,
    this.offsetDy = 0,
  });

  final IconData icon;
  final String label;
  final double rotation;
  final double offsetDy;

  static _SignMotion forToken(String signTokenId) {
    return switch (signTokenId) {
      'hello' => const _SignMotion(
        icon: Icons.waving_hand_rounded,
        label: 'Wave hello',
        rotation: -0.25,
      ),
      'how' => const _SignMotion(
        icon: Icons.help_outline_rounded,
        label: 'How?',
        rotation: 0.1,
      ),
      'you' => const _SignMotion(
        icon: Icons.person_outline_rounded,
        label: 'You',
      ),
      'today' => const _SignMotion(icon: Icons.today_rounded, label: 'Today'),
      'thank_you' => const _SignMotion(
        icon: Icons.favorite_border_rounded,
        label: 'Thanks',
      ),
      'please' => const _SignMotion(
        icon: Icons.volunteer_activism_rounded,
        label: 'Please',
      ),
      'help' => const _SignMotion(
        icon: Icons.sos_rounded,
        label: 'Help',
        offsetDy: -8,
      ),
      'yes' => const _SignMotion(
        icon: Icons.check_circle_outline_rounded,
        label: 'Yes',
      ),
      'no' => const _SignMotion(icon: Icons.cancel_outlined, label: 'No'),
      'good' => const _SignMotion(
        icon: Icons.thumb_up_alt_rounded,
        label: 'Good',
        rotation: 0.15,
        offsetDy: -10,
      ),
      'name' => const _SignMotion(icon: Icons.badge_outlined, label: 'Name'),
      'my' => const _SignMotion(icon: Icons.back_hand_rounded, label: 'My'),
      'is' => const _SignMotion(icon: Icons.gesture_rounded, label: 'Is'),
      'looking' => const _SignMotion(
        icon: Icons.visibility_outlined,
        label: 'Look',
      ),
      'everything' => const _SignMotion(
        icon: Icons.all_inclusive_rounded,
        label: 'All',
      ),
      _ => const _SignMotion(icon: Icons.sign_language_rounded, label: 'Sign'),
    };
  }
}
