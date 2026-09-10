import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';

class ProfileScreen extends StatelessWidget {
  final ProfileModel profile;

  const ProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    child: Text(
                      profile.fullName.isNotEmpty ? profile.fullName[0] : 'م',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.jobTitleName ?? 'بدون مسمى وظيفي',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'بيانات الحساب',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
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
                  const Divider(),
                  _line(context, 'حالة الحساب', profile.active ? 'نشط' : 'موقوف'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'يمكن تعديل إعدادات الأمان والبصمة من شاشة «الإعدادات» في القائمة الجانبية.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
}
