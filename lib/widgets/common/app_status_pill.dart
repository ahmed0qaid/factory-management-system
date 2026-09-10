import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

class AppStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const AppStatusPill({
    Key? key,
    required this.label,
    required this.color,
  }) : super(key: key);

  factory AppStatusPill.success(String label) => AppStatusPill(label: label, color: AppColors.success);
  factory AppStatusPill.warning(String label) => AppStatusPill(label: label, color: AppColors.warning);
  factory AppStatusPill.danger(String label) => AppStatusPill(label: label, color: AppColors.danger);
  factory AppStatusPill.info(String label) => AppStatusPill(label: label, color: AppColors.primary);
  factory AppStatusPill.neutral(String label) => AppStatusPill(label: label, color: AppColors.secondary);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.semanticBackground(color),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
