import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppFormDialog extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, void Function(void Function()) setState) builder;
  final String submitText;
  final String cancelText;
  final Future<bool> Function() onSubmit;

  const AppFormDialog({
    Key? key,
    required this.title,
    required this.builder,
    required this.onSubmit,
    this.submitText = 'حفظ',
    this.cancelText = 'إلغاء',
  }) : super(key: key);

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget Function(BuildContext context, void Function(void Function()) setState) builder,
    required Future<bool> Function() onSubmit,
    String submitText = 'حفظ',
    String cancelText = 'إلغاء',
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppFormDialog(
        title: title,
        builder: builder,
        onSubmit: onSubmit,
        submitText: submitText,
        cancelText: cancelText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: builder(context, setState),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
              child: Text(cancelText, style: const TextStyle(color: AppColors.secondary)),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setState(() => isSubmitting = true);
                        try {
                          final success = await onSubmit();
                          if (success && context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(submitText),
            ),
          ],
        );
      },
    );
  }
}
