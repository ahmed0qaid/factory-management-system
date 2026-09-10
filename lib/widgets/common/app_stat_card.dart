import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icon_sizes.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'app_card.dart';

/// Standardized Responsive HR Stat Card (AppStatCard)
///
/// Supports Dynamic State Evaluation:
/// - Active (isActive == true): Pure White Background, Colored Border, Colored Title & Value.
/// - Inactive (isActive == false): Dark Translucent / Subtle Neutral Background, Neutral Border & Text.
class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isActive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Refined Luxury Card Colors & Styling
    final effectiveBg = Colors.white;
    final effectiveBorder = isActive
        ? color.withValues(alpha: .35)
        : AppColors.border;
    final effectiveValueColor = isActive ? color : AppColors.textMuted;
    final effectiveTitleColor = isActive
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final effectiveIconBg = isActive
        ? color.withValues(alpha: .08)
        : AppColors.surfaceContainer;
    final effectiveIconColor = isActive ? color : AppColors.textMuted;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      backgroundColor: effectiveBg,
      borderColor: effectiveBorder,
      borderWidth: isActive ? 1.2 : 1.0,
      elevated: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: effectiveIconBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: .18)
                    : AppColors.border.withValues(alpha: .5),
              ),
            ),
            child: Icon(icon, color: effectiveIconColor, size: AppIconSizes.standard),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: effectiveTitleColor,
              fontWeight: isActive ? FontWeight.normal : FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: effectiveValueColor,
              
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: effectiveValueColor.withValues(alpha: .8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}



