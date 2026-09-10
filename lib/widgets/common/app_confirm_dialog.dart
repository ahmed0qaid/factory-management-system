import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const AppConfirmDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.confirmText = 'تأكيد',
    this.cancelText = 'إلغاء',
    this.isDestructive = false,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Text(
        content,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText, style: const TextStyle(color: AppColors.secondary)),
        ),
        FilledButton(
          onPressed: onConfirm,
          style: isDestructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}
