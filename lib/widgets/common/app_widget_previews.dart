import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'app_action_card.dart';
import 'app_stat_card.dart';
import 'app_status_badge.dart';

/// Previews for Core HR Shared Widgets.
/// Serves as visual benchmark reference for design consistency.
class AppWidgetPreviewsScreen extends StatelessWidget {
  const AppWidgetPreviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاينة المكونات المشتركة - HR System')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('1. AppStatCard Variants', style: TextStyle(fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 160,
                height: 136,
                child: AppStatCard(
                  title: 'الرصيد المتاح للسلفة',
                  value: '5,000 ج.م',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(
                width: 160,
                height: 136,
                child: AppStatCard(
                  title: 'إجمالي الجزاءات المقيدة للشهر الحالي',
                  value: '250 ج.م',
                  subtitle: '2 جزاء محرر',
                  icon: Icons.gavel_outlined,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(
                width: 160,
                height: 136,
                child: AppStatCard(
                  title: 'توقفات خطوط الإنتاج',
                  value: '3 توقفات',
                  icon: Icons.factory_outlined,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            '2. AppStatusBadge Variants',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusBadge(
                label: 'حاضر (Success)',
                color: AppColors.success,
                icon: Icons.check_circle_outline,
              ),
              AppStatusBadge(
                label: 'متأخر (Warning)',
                color: AppColors.warning,
                icon: Icons.access_time,
              ),
              AppStatusBadge(
                label: 'غائب (Danger)',
                color: AppColors.danger,
                icon: Icons.cancel_outlined,
              ),
              AppStatusBadge(
                label: 'محايد (Neutral)',
                color: AppColors.secondary,
                icon: Icons.info_outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            '3. AppActionCard Variants',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppActionCard(
            title: 'عرض سجل الدوام التفصيلي',
            subtitle: 'مراجعة أوقات الحضور والانصراف السابقة',
            icon: Icons.timeline,
            color: AppColors.primary,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          AppActionCard(
            title: 'طلب إجازة جديدة',
            subtitle: 'تقديم طلب إجازة اعتيادية أو عارضة',
            icon: Icons.event_available_outlined,
            color: AppColors.tertiary,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            '4. Form Inputs & Buttons',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          const TextField(
            decoration: InputDecoration(
              labelText: 'اسم الموظف بالكامل',
              hintText: 'أدخل الاسم الثلاثي',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.check),
            label: const Text('حفظ التغييرات (Primary)'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.close),
            label: const Text('إلغاء الأمر (Secondary)'),
          ),
        ],
      ),
    );
  }
}
