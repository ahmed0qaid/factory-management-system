import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/formatters.dart';
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

  void _reload() {
    setState(() => _future = _service.getAdvanceBalance());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    return AppScaffold(
      title: 'تفاصيل رصيد السلفة',
      body: FutureBuilder<AdvanceBalanceInfo>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const AppLoadingState(label: 'جاري تحميل الرصيد');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل الرصيد',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final balance = snapshot.data!;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الفترة المالية الحالية',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _line('من تاريخ', Formatters.date(balance.periodStart)),
                        _line('إلى تاريخ', Formatters.date(balance.periodEnd)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الدوام والمستحقات',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 12),
                  AppCard(
                    borderColor: scheme.error.withValues(alpha: .25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الخصومات المحتسبة',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 12),
                  AppCard(
                    backgroundColor: balance.availableBalance > 0
                        ? semantic.successContainer.withValues(alpha: .48)
                        : scheme.surfaceContainerLow,
                    borderColor: balance.availableBalance > 0
                        ? semantic.success.withValues(alpha: .32)
                        : scheme.outlineVariant,
                    borderWidth: 1.2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الخلاصة',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _line(
                          'الرصيد المتاح للسلفة',
                          Formatters.money(balance.availableBalance),
                          isBold: true,
                          color: balance.availableBalance > 0
                              ? semantic.success
                              : scheme.onSurfaceVariant,
                        ),
                        _line(
                          'إمكانية طلب سلفة',
                          balance.canRequestAdvance ? 'نعم' : 'لا',
                          isBold: true,
                          color: balance.canRequestAdvance
                              ? semantic.success
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'يتم حساب الرصيد المتاح بناءً على أيام الحضور خلال الفترة المالية الحالية، بعد خصم السلف السابقة والجزاءات المسجلة.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
