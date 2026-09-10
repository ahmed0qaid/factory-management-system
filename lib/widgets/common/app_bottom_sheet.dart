import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;

  const AppBottomSheet({
    Key? key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  }) : super(key: key);

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AppBottomSheet(title: title, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
          ],
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
