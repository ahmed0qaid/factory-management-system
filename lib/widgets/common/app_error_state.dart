import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'app_card.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      backgroundColor: AppColors.semanticBackground(AppColors.danger),
      borderColor: AppColors.infoCardBorder(AppColors.danger),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: textTheme.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }
}
