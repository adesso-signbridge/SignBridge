import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MicroserviceTabScreen extends StatelessWidget {
  const MicroserviceTabScreen({
    super.key,
    required this.serviceName,
    required this.titleFuture,
  });

  final String serviceName;
  final Future<String> titleFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: titleFuture,
      builder: (context, snapshot) {
        final title = snapshot.data ?? 'Loading...';
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                serviceName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
