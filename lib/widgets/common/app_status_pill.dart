import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_semantic_colors.dart';

enum AppStatusTone { success, warning, danger, info, neutral }

class AppStatusPill extends StatelessWidget {
  final String label;
  final Color? color;
  final AppStatusTone tone;

  const AppStatusPill({
    super.key,
    required this.label,
    this.color,
    this.tone = AppStatusTone.neutral,
  });

  factory AppStatusPill.success(String label) =>
      AppStatusPill(label: label, tone: AppStatusTone.success);
  factory AppStatusPill.warning(String label) =>
      AppStatusPill(label: label, tone: AppStatusTone.warning);
  factory AppStatusPill.danger(String label) =>
      AppStatusPill(label: label, tone: AppStatusTone.danger);
  factory AppStatusPill.info(String label) =>
      AppStatusPill(label: label, tone: AppStatusTone.info);
  factory AppStatusPill.neutral(String label) =>
      AppStatusPill(label: label, tone: AppStatusTone.neutral);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    final effectiveColor = color ?? switch (tone) {
      AppStatusTone.success => semantic.success,
      AppStatusTone.warning => semantic.warning,
      AppStatusTone.danger => scheme.error,
      AppStatusTone.info => scheme.primary,
      AppStatusTone.neutral => scheme.onSurfaceVariant,
    };

    final background = switch (tone) {
      AppStatusTone.success when color == null => semantic.successContainer,
      AppStatusTone.warning when color == null => semantic.warningContainer,
      AppStatusTone.danger when color == null => scheme.errorContainer,
      AppStatusTone.info when color == null => scheme.primaryContainer,
      AppStatusTone.neutral when color == null => scheme.surfaceContainerHighest,
      _ => effectiveColor.withValues(alpha: .10),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
