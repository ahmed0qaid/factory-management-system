import 'package:flutter/material.dart';

import '../../models/leave_model.dart';
import '../../services/employee_service.dart';
import '../../utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_status_pill.dart';
import '../../widgets/common/app_list_item.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  final _service = EmployeeService();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyLeaves();
  }

  void _reload() => setState(() => _future = _service.getMyLeaves());

  Future<void> _showRequestDialog() async {
    final type = TextEditingController();
    final reason = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    await AppFormDialog.show(
      context,
      title: 'طلب إجازة',
      submitText: 'إرسال',
      builder: (context, setStateBuilder) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFormField(
            controller: type,
            labelText: 'نوع الإجازة (مرضية، سنوية، الخ)',
            validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال نوع الإجازة' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setStateBuilder(() => startDate = picked);
                  },
                  child: Text(
                    startDate == null ? 'تاريخ البداية' : Formatters.date(startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setStateBuilder(() => endDate = picked);
                  },
                  child: Text(
                    endDate == null ? 'تاريخ النهاية' : Formatters.date(endDate!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppFormField(
            controller: reason,
            labelText: 'السبب (اختياري)',
          ),
        ],
      ),
      onSubmit: () async {
        if (type.text.isEmpty || startDate == null || endDate == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يرجى تعبئة جميع الحقول الإلزامية')),
            );
          }
          return false;
        }
        await _service.requestLeave(
          leaveType: type.text.trim(),
          startDate: startDate!.toIso8601String(),
          endDate: endDate!.toIso8601String(),
          reason: reason.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال طلب الإجازة للإدارة.')),
          );
          _reload();
        }
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'طلبات الإجازة',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('طلب إجازة'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('لا توجد طلبات إجازة.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final a = LeaveModel.fromMap(items[i].data);
              return AppListItem(
                title: Text('إجازة ${a.leaveType}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('من: ${Formatters.date(a.startDate)} إلى ${Formatters.date(a.endDate)}'),
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


