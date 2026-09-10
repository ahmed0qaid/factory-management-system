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
import '../../widgets/common/app_list_item.dart';
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ملخص الرصيد الحالي',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                      const Divider(height: 20),
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
                const SizedBox(height: 16),
                if (balance.availableBalance <= 0)
                  AppCard(
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadingRequestForm ? null : _showRequestDialog,
        icon: _loadingRequestForm
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_loadingRequestForm ? 'جاري التحقق...' : 'طلب سلفة'),
      ),
      body: FutureBuilder<List<AdvanceModel>>(
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
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final advance = items[index];
                    return AppListItem(
                      title: Text(
                        'سلفة ${Formatters.money(advance.principalAmount)}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تاريخ الطلب: ${Formatters.date(advance.requestDate)}',
                          ),
                          if (advance.remainingAmount > 0)
                            Text(
                              'المتبقي: ${Formatters.money(advance.remainingAmount)}',
                            ),
                          if (advance.reason?.trim().isNotEmpty == true)
                            Text('السبب: ${advance.reason}'),
                        ],
                      ),
                      trailing: _status(advance.status),
                    );
                  },
                ),
              ),
            ),
          );
        },
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
