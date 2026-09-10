import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
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
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.contentPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: ListTile(
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        leading: leading,
        title: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          child: title,
        ),
        subtitle: subtitle != null
            ? DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: subtitle!,
                ),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}
