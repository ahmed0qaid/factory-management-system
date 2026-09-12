import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'app_card.dart';

class AppListItem extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? contentPadding;

  const AppListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: ListTile(
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
        leading: leading,
        title: DefaultTextStyle(
          style:
              theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(color: scheme.onSurface),
          child: title,
        ),
        subtitle: subtitle != null
            ? DefaultTextStyle(
                style:
                    theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ) ??
                    TextStyle(color: scheme.onSurfaceVariant),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: subtitle!,
                ),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}
