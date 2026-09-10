import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'app_card.dart';

class AppEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: textTheme.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
