import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/home/home_service.dart';

/// iPhone-style SOS countdown before auto-calling emergency services.
class SosCountdownDialog extends StatefulWidget {
  const SosCountdownDialog({
    super.key,
    required this.uiCopy,
    this.seconds = 3,
  });

  final HomeUiCopy uiCopy;
  final int seconds;

  @override
  State<SosCountdownDialog> createState() => _SosCountdownDialogState();
}

class _SosCountdownDialogState extends State<SosCountdownDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) {
      return;
    }

    if (_remaining <= 1) {
      _timer?.cancel();
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _remaining--);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.white,
        title: Text(
          widget.uiCopy.sosCountdownTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_remaining',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: AppColors.emergencyRed,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.uiCopy.sosCountdownBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.uiCopy.sosCountdownCancelLabel),
          ),
        ],
      ),
    );
  }
}
