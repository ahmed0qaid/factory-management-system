import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'app_card.dart';

class AppLoadingState extends StatelessWidget {
  final String label;

  const AppLoadingState({super.key, this.label = 'جاري تحميل البيانات'});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
