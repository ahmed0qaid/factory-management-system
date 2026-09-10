import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../services/employee_service.dart';
import '../../utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_status_pill.dart';
import '../../widgets/common/app_list_item.dart';

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  final _service = EmployeeService();
  late Future<List<AdvanceModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyAdvances();
  }

  void _reload() => setState(() => _future = _service.getMyAdvances());

  Future<void> _showRequestDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final balance = await _service.getAdvanceBalance();
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      final amount = TextEditingController();
      final reason = TextEditingController();

      await AppFormDialog.show(
        context,
        title: 'طلب سلفة',
        submitText: 'إرسال',
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفترة: ${Formatters.date(balance.periodStart)} - ${Formatters.date(balance.periodEnd)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أيام الحضور: ${balance.attendanceDays} من ${balance.workingDaysInPeriod} يوم عمل',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المستحق حتى اليوم: ${Formatters.money(balance.accruedSalary)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السلف السابقة: ${Formatters.money(balance.previousAdvances)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي الجزاءات: ${Formatters.money(balance.penaltiesAmount)}',
                    ),
                    const Divider(),
                    Text(
                      'الرصيد المتاح للسلفة: ${Formatters.money(balance.availableBalance)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: balance.availableBalance > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (balance.availableBalance <= 0)
                const Text(
                  'لا يوجد رصيد متاح للسلفة حاليًا.',
                  style: TextStyle(
                    color: AppColors.danger,
                  ),
                )
              else ...[
                AppFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  labelText: 'المبلغ المطلوب',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'يرجى إدخال المبلغ';
                    final v = num.tryParse(val.trim());
                    if (v == null || v <= 0) return 'مبلغ غير صحيح';
                    if (v > balance.availableBalance) return 'المبلغ أكبر من الرصيد المتاح';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: reason,
                  labelText: 'السبب (اختياري)',
                ),
              ],
            ],
          );
        },
        onSubmit: () async {
          if (balance.availableBalance <= 0) return false;
          final valAmount = num.tryParse(amount.text.trim());
          if (valAmount == null || valAmount <= 0) return false;

          await _service.requestAdvance(
            amount: valAmount,
            reason: reason.text.trim(),
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إرسال طلب السلفة للإدارة.')),
            );
            _reload();
          }
          return true;
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading if error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('طلب سلفة'),
      ),
      body: FutureBuilder<List<AdvanceModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('لا توجد سلف.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final a = items[i];
              return AppListItem(
                title: Text('سلفة ${Formatters.date(a.requestDate)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المبلغ: ${Formatters.money(a.principalAmount)}'),
                    if (a.reason != null && a.reason!.isNotEmpty)
                      Text('السبب: ${a.reason}'),
                  ],
                ),
                trailing: AppStatusPill(
                  label: a.status == 'approved' ? 'موافق عليها' : a.status == 'rejected' ? 'مرفوضة' : 'قيد المراجعة',
                  color: a.status == 'approved' ? AppColors.success : a.status == 'rejected' ? AppColors.danger : AppColors.warning,
                ),
              );
            },
          );
        },
      ),
    );
  }
}


