import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveBackground = backgroundColor ?? AppColors.surfaceContainerLow;
    final radius = AppRadius.card;

    return Padding(
      padding: margin,
      child: Material(
        color: effectiveBackground,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: effectiveBackground,
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? AppColors.border,
                width: borderWidth,
              ),
              boxShadow: elevated ? AppShadows.subtle(scheme.shadow) : null,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
