import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../services/employee_service.dart';
import '../../utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class AdvanceBalanceDetailsScreen extends StatefulWidget {
  const AdvanceBalanceDetailsScreen({super.key});

  @override
  State<AdvanceBalanceDetailsScreen> createState() =>
      _AdvanceBalanceDetailsScreenState();
}

class _AdvanceBalanceDetailsScreenState
    extends State<AdvanceBalanceDetailsScreen> {
  final _service = EmployeeService();
  late Future<AdvanceBalanceInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAdvanceBalance();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تفاصيل رصيد السلفة',
      body: FutureBuilder<AdvanceBalanceInfo>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError)
            return const AppLoadingState(label: 'جاري تحميل الرصيد');
          if (snapshot.hasError)
            return AppErrorState(
              title: 'خطأ',
              message: '${snapshot.error}',
              onRetry: () => setState(() => _future = _service.getAdvanceBalance()),
            );

          final balance = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفترة المالية الحالية',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _line('من تاريخ', Formatters.date(balance.periodStart)),
                    _line('إلى تاريخ', Formatters.date(balance.periodEnd)),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الدوام والمستحقات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _line(
                      'المستحق الشهري الأساسي',
                      Formatters.money(balance.monthlyEntitlement),
                    ),
                    _line(
                      'أيام العمل في الفترة',
                      '${balance.workingDaysInPeriod} يوم',
                    ),
                    _line(
                      'أيام الحضور الفعلية',
                      '${balance.attendanceDays} يوم',
                    ),
                    const Divider(),
                    _line(
                      'المستحق حتى اليوم',
                      Formatters.money(balance.accruedSalary),
                      isBold: true,
                    ),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الخصومات المحتسبة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _line(
                      'السلف السابقة (معتمدة/معلقة)',
                      Formatters.money(balance.previousAdvances),
                    ),
                    _line(
                      'الجزاءات (معتمدة/معلقة)',
                      Formatters.money(balance.penaltiesAmount),
                    ),
                  ],
                ),
              ),
              AppCard(
                backgroundColor: Colors.white,
                borderColor: balance.availableBalance > 0
                    ? AppColors.secondary.withValues(alpha: .35)
                    : AppColors.border,
                borderWidth: 1.2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الخلاصة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _line(
                      'الرصيد المتاح للسلفة',
                      Formatters.money(balance.availableBalance),
                      isBold: true,
                      color: balance.availableBalance > 0
                          ? AppColors.secondary
                          : AppColors.textMuted,
                    ),
                    _line(
                      'إمكانية طلب سلفة',
                      balance.canRequestAdvance ? 'نعم' : 'لا',
                      isBold: true,
                      color: balance.canRequestAdvance
                          ? AppColors.secondary
                          : AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ملاحظة: يتم حساب الرصيد المتاح بناءً على أيام الحضور خلال الفترة المالية الحالية، بعد خصم السلف السابقة والجزاءات المسجلة.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(
    String title,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(title)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.normal : FontWeight.normal,
                color: color,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


