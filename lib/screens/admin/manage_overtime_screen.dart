// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../models/overtime_record_model.dart';
import '../../models/profile_model.dart';
import '../../services/admin_biometrics_service.dart';
import '../../services/admin_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManageOvertimeScreen extends StatefulWidget {
  final String companyId;
  const ManageOvertimeScreen({super.key, required this.companyId});

  @override
  State<ManageOvertimeScreen> createState() => _ManageOvertimeScreenState();
}

class _ManageOvertimeScreenState extends State<ManageOvertimeScreen> {
  final _biometricsService = AdminBiometricsService();
  final _adminService = AdminService();

  bool _isLoading = true;
  List<OvertimeRecordModel> _pendingOvertime = [];
  Map<String, ProfileModel> _employees = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final records = await _biometricsService.getPendingOvertime();
      final emps = await _adminService.getEmployees(limit: 500);
      final empMap = {for (var e in emps) e.id: e};

      if (mounted) {
        setState(() {
          _pendingOvertime = records;
          _employees = empMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _biometricsService.updateOvertimeStatus(id, status);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث الحالة بنجاح')));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _showPayDialog(OvertimeRecordModel record, ProfileModel emp) {
    final hourlyRate = emp.baseSalary > 0 ? (emp.baseSalary / 30 / 8) : 0;
    final suggestedAmount = hourlyRate * 1.5 * (record.overtimeMinutes / 60);
    final controller = TextEditingController(
      text: suggestedAmount.toStringAsFixed(2),
    );

    AppFormDialog.show(
      context,
      title: 'دفع الإضافي',
      submitText: 'اعتماد الدفع',
      onSubmit: () async {
        final amt = double.tryParse(controller.text);
        if (amt == null || amt < 0) return false;
        try {
          await _biometricsService.payOvertime(record.id, amt);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تسجيل الدفع بنجاح')),
            );
          }
          _loadData();
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
          }
          return false;
        }
      },
      builder: (context, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الموظف: ${emp.fullName}'),
            const SizedBox(height: 4),
            Text('الدقائق: ${record.overtimeMinutes} دقيقة'),
            const SizedBox(height: 16),
            AppFormField(
              controller: controller,
              labelText: 'المبلغ المستحق',
              keyboardType: TextInputType.number,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إدارة الوقت الإضافي',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingOvertime.isEmpty
          ? const Center(
              child: Text(
                'لا توجد سجلات إضافي معلقة',
                style: TextStyle(fontSize: 18),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pendingOvertime.length,
                itemBuilder: (context, index) {
                  final record = _pendingOvertime[index];
                  final emp = _employees[record.employeeId];
                  return _OvertimeCard(
                    record: record,
                    employeeName: emp?.fullName ?? 'غير معروف',
                    onApprove: () => _updateStatus(record.id, 'approved'),
                    onReject: () => _updateStatus(record.id, 'rejected'),
                    onPay: emp == null
                        ? null
                        : () => _showPayDialog(record, emp),
                  );
                },
              ),
            ),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  final OvertimeRecordModel record;
  final String employeeName;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onPay;

  const _OvertimeCard({
    required this.record,
    required this.employeeName,
    required this.onApprove,
    required this.onReject,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  employeeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(record.approvalStatus),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow('تاريخ العمل', Formatters.date(record.workDate)),
          _InfoRow('نهاية الوردية', Formatters.time(record.shiftEnd)),
          _InfoRow('الخروج الفعلي', Formatters.time(record.actualCheckOut)),
          _InfoRow('دقائق الإضافي', '${record.overtimeMinutes} دقيقة'),
          const SizedBox(height: 16),
          if (record.approvalStatus == 'pending')
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('اعتماد'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusPill(record.approvalStatus),
            ),
          if (onPay != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('دفع نقدي فوري'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    switch (status) {
      case 'approved':
        return AppStatusPill.success('معتمد');
      case 'rejected':
        return AppStatusPill.danger('مرفوض');
      case 'pending':
      default:
        return AppStatusPill.warning('بانتظار الاعتماد');
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(),
            ),
          ),
        ],
      ),
    );
  }
}


