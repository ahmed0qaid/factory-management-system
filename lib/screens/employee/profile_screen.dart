import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_status_pill.dart';

class ProfileScreen extends StatelessWidget {
  final ProfileModel profile;

  const ProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppCard(
              elevated: true,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Text(
                      profile.fullName.isNotEmpty ? profile.fullName[0] : 'م',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                  Text(
                    profile.fullName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profile.jobTitleName ?? 'بدون مسمى وظيفي',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  profile.active
                      ? AppStatusPill.success('الحساب نشط')
                      : AppStatusPill.danger('الحساب موقوف'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'بيانات الحساب',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  _line(context, 'رقم الموظف', profile.employeeNumber),
                  const Divider(),
                  _line(context, 'القسم', profile.departmentName ?? '-'),
                  const Divider(),
                  _line(
                    context,
                    'المسمى الوظيفي',
                    profile.jobTitleName ?? '-',
                  ),
                  const Divider(),
                  _line(context, 'الدور في النظام', profile.roleLabel),
                  const Divider(),
                  _line(context, 'الهاتف', profile.phone ?? '-'),
                  const Divider(),
                  _line(
                    context,
                    'الراتب الأساسي',
                    Formatters.money(profile.baseSalary),
                  ),
                  const Divider(),
                  _line(
                    context,
                    'المكافأة الشهرية',
                    Formatters.money(profile.monthlyBonus),
                  ),
                  const Divider(),
                  _line(
                    context,
                    'المستحق الشهري',
                    Formatters.money(profile.monthlyEntitlement),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            Text(
              'يمكن تعديل إعدادات الأمان والبصمة من شاشة «الإعدادات» في القائمة الجانبية.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
