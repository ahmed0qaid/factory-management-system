import 'package:flutter/material.dart';

import '../../theme/app_icon_sizes.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'app_card.dart';

/// Standardized responsive stat card.
///
/// Structural surfaces remain neutral. The supplied accent color is used only
/// for the icon/value emphasis when the metric is active, keeping dashboards
/// readable instead of turning every card into a different color block.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accent = _adaptColor(color, theme.brightness);

    final background = scheme.surfaceContainerLowest;
    final border = isActive
        ? accent.withValues(alpha: theme.brightness == Brightness.dark ? .38 : .24)
        : scheme.outlineVariant.withValues(alpha: .65);
    final valueColor = isActive ? accent : scheme.onSurfaceVariant;
    final titleColor = isActive ? scheme.onSurface : scheme.onSurfaceVariant;
    final iconBackground = isActive
        ? accent.withValues(alpha: theme.brightness == Brightness.dark ? .16 : .08)
        : scheme.surfaceContainerHigh;
    final iconColor = isActive ? accent : scheme.onSurfaceVariant;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      backgroundColor: background,
      borderColor: border,
      borderWidth: isActive ? 1.1 : 1,
      elevated: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.hasBoundedHeight &&
              constraints.maxHeight < 120;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: AppIconSizes.small,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: AppIconSizes.standard,
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Color _adaptColor(Color source, Brightness brightness) {
    final sourceBrightness = ThemeData.estimateBrightnessForColor(source);
    if (brightness == Brightness.dark &&
        sourceBrightness == Brightness.dark) {
      return Color.lerp(source, Colors.white, .38)!;
    }
    if (brightness == Brightness.light &&
        sourceBrightness == Brightness.light) {
      return Color.lerp(source, Colors.black, .36)!;
    }
    return source;
  }
}
