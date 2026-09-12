import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'app_card.dart';

class AppActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const AppActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final accent = _adaptColor(color, theme.brightness);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: theme.brightness == Brightness.dark ? .18 : .09,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            isRtl ? Icons.chevron_left : Icons.chevron_right,
            color: scheme.onSurfaceVariant,
          ),
        ],
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
