import 'package:flutter/material.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(
              actionIcon ??
                  (Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back
                      : Icons.arrow_forward),
              size: 18,
            ),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}
