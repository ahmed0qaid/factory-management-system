import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class AppFormDialog extends StatelessWidget {
  final String title;
  final Widget Function(
    BuildContext context,
    void Function(void Function()) setState,
  )
  builder;
  final String submitText;
  final String cancelText;
  final Future<bool> Function() onSubmit;

  const AppFormDialog({
    super.key,
    required this.title,
    required this.builder,
    required this.onSubmit,
    this.submitText = 'حفظ',
    this.cancelText = 'إلغاء',
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget Function(
      BuildContext context,
      void Function(void Function()) setState,
    )
    builder,
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
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return AlertDialog(
          title: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(key: formKey, child: builder(context, setState)),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(cancelText),
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
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(submitText),
            ),
          ],
        );
      },
    );
  }
}
