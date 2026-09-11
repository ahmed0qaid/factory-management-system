import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_status_pill.dart';

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  final _service = EmployeeService();
  late Future<List<AdvanceModel>> _future;
  bool _loadingRequestForm = false;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyAdvances();
  }

  void _reload() => setState(() => _future = _service.getMyAdvances());

  Future<void> _showRequestDialog() async {
    if (_loadingRequestForm) return;
    setState(() => _loadingRequestForm = true);

    try {
      final balance = await _service.getAdvanceBalance();
      if (!mounted) return;

      final amount = TextEditingController();
      final reason = TextEditingController();
      try {
        await AppFormDialog.show(
          context,
          title: 'طلب سلفة',
          submitText: 'إرسال الطلب',
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ملخص الرصيد الحالي',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SummaryLine(
                        'الفترة',
                        '${Formatters.date(balance.periodStart)} — ${Formatters.date(balance.periodEnd)}',
                      ),
                      _SummaryLine(
                        'الحضور',
                        '${balance.attendanceDays} من ${balance.workingDaysInPeriod} يوم عمل',
                      ),
                      _SummaryLine(
                        'المستحق حتى اليوم',
                        Formatters.money(balance.accruedSalary),
                      ),
                      _SummaryLine(
                        'السلف السابقة',
                        Formatters.money(balance.previousAdvances),
                      ),
                      _SummaryLine(
                        'الجزاءات',
                        Formatters.money(balance.penaltiesAmount),
                      ),
                      const Divider(height: 18),
                      _SummaryLine(
                        'الرصيد المتاح',
                        Formatters.money(balance.availableBalance),
                        strong: true,
                        valueColor: balance.availableBalance > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (balance.availableBalance <= 0)
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    borderColor:
                        Theme.of(context).colorScheme.error.withValues(alpha: .3),
                    child: const Text(
                      'لا يوجد رصيد متاح للسلفة حاليًا. لا يمكن إرسال طلب جديد.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  AppFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    labelText: 'المبلغ المطلوب',
                    prefixIcon: Icons.payments_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل المبلغ المطلوب';
                      }
                      final parsed = num.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل مبلغًا صحيحًا أكبر من الصفر';
                      }
                      if (parsed > balance.availableBalance) {
                        return 'المبلغ أكبر من الرصيد المتاح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppFormField(
                    controller: reason,
                    labelText: 'سبب السلفة (اختياري)',
                    prefixIcon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                ],
              ],
            );
          },
          onSubmit: () async {
            if (balance.availableBalance <= 0) return false;
            final requested = num.tryParse(amount.text.trim());
            if (requested == null ||
                requested <= 0 ||
                requested > balance.availableBalance) {
              return false;
            }
            try {
              await _service.requestAdvance(
                amount: requested,
                reason: reason.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال طلب السلفة للإدارة.')),
                );
                _reload();
              }
              return true;
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تعذر إرسال طلب السلفة: $error')),
                );
              }
              return false;
            }
          },
        );
      } finally {
        amount.dispose();
        reason.dispose();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حساب الرصيد المتاح: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRequestForm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdvanceModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(label: 'جاري تحميل السلف');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'تعذر تحميل السلف',
            message: '${snapshot.error}',
            onRetry: _reload,
          );
        }

        final items = snapshot.data ?? const <AdvanceModel>[];
        if (items.isEmpty) {
          return AppEmptyState(
            title: 'لا توجد سلف',
            message: 'لم ترسل أي طلب سلفة حتى الآن.',
            icon: Icons.account_balance_wallet_outlined,
            actionLabel: 'طلب سلفة',
            onAction: _showRequestDialog,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
                children: [
                  _buildHeader(context, items.length),
                  const SizedBox(height: 12),
                  for (final advance in items) _buildAdvanceCard(context, advance),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 19,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات السلف',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count طلب مسجل',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loadingRequestForm ? null : _showRequestDialog,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            icon: _loadingRequestForm
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 18),
            label: Text(_loadingRequestForm ? 'جاري...' : 'طلب جديد'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceCard(BuildContext context, AdvanceModel advance) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = advance.remainingAmount;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _status(advance.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Formatters.money(advance.principalAmount),
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AdvanceMeta(
                  icon: Icons.calendar_today_outlined,
                  label: 'تاريخ الطلب',
                  value: Formatters.date(advance.requestDate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AdvanceMeta(
                  icon: Icons.payments_outlined,
                  label: 'المتبقي',
                  value: remaining > 0
                      ? Formatters.money(remaining)
                      : 'لا يوجد متبقٍ',
                  valueColor: remaining > 0 ? null : AppColors.success,
                ),
              ),
            ],
          ),
          if (advance.reason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      advance.reason!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _status(String status) {
    return switch (status) {
      'approved' => AppStatusPill.success('معتمدة'),
      'paid' => AppStatusPill.success('مصروفة'),
      'rejected' => AppStatusPill.danger('مرفوضة'),
      _ => AppStatusPill.warning('قيد المراجعة'),
    };
  }
}

class _AdvanceMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _AdvanceMeta({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  const _SummaryLine(
    this.label,
    this.value, {
    this.strong = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: strong ? FontWeight.bold : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
