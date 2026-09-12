import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = _adaptCustomColor(color, theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(
          alpha: theme.brightness == Brightness.dark ? .18 : .10,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: effectiveColor.withValues(
            alpha: theme.brightness == Brightness.dark ? .48 : .30,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _adaptCustomColor(Color source, Brightness brightness) {
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
