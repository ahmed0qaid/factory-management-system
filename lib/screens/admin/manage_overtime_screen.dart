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
  String? _processingId;
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
      final recordsFuture = _biometricsService.getPendingOvertime();
      final employeesFuture = _adminService.getEmployees(limit: 500);
      final records = await recordsFuture;
      final employees = await employeesFuture;
      if (!mounted) return;
      setState(() {
        _pendingOvertime = records;
        _employees = {for (final employee in employees) employee.id: employee};
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل سجلات الوقت الإضافي: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmStatusChange(
    OvertimeRecordModel record,
    String status,
  ) async {
    final employee = _employees[record.employeeId];
    final approving = status == 'approved';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(approving ? 'اعتماد الوقت الإضافي' : 'رفض الوقت الإضافي'),
            content: Text(
              '${approving ? 'اعتماد' : 'رفض'} ${record.overtimeMinutes} دقيقة إضافية للموظف ${employee?.fullName ?? 'غير معروف'} بتاريخ ${Formatters.date(record.workDate)}؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(approving ? 'اعتماد' : 'رفض'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _updateStatus(record.id, status);
  }

  Future<void> _updateStatus(String id, String status) async {
    setState(() => _processingId = id);
    try {
      await _biometricsService.updateOvertimeStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'تم اعتماد الوقت الإضافي.'
                : 'تم رفض الوقت الإضافي.',
          ),
        ),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث حالة الوقت الإضافي: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _showPayDialog(
    OvertimeRecordModel record,
    ProfileModel employee,
  ) async {
    if (record.approvalStatus != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اعتماد الوقت الإضافي قبل تسجيل الدفع.'),
        ),
      );
      return;
    }
    if (record.paymentStatus == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم دفع هذا السجل مسبقًا.')),
      );
      return;
    }

    final hourlyRate =
        employee.baseSalary > 0 ? (employee.baseSalary / 30 / 8) : 0;
    final suggestedAmount =
        hourlyRate * 1.5 * (record.overtimeMinutes / 60);
    final controller = TextEditingController(
      text: suggestedAmount.toStringAsFixed(2),
    );

    try {
      await AppFormDialog.show<void>(
        context,
        title: 'تسجيل دفع الوقت الإضافي',
        submitText: 'تأكيد الدفع',
        onSubmit: () async {
          final amount = double.tryParse(controller.text.trim());
          if (amount == null || amount < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('أدخل مبلغًا صحيحًا.')),
            );
            return false;
          }
          try {
            await _biometricsService.payOvertime(record.id, amount);
            if (!mounted) return false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم تسجيل دفع ${Formatters.money(amount)} للموظف ${employee.fullName}.',
                ),
              ),
            );
            await _loadData();
            return true;
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تعذر تسجيل الدفع: $error')),
              );
            }
            return false;
          }
        },
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                employee.fullName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${employee.employeeNumber} • ${Formatters.date(record.workDate)}',
              ),
              const SizedBox(height: 8),
              Text(
                'الوقت المعتمد: ${Formatters.minutesToHours(record.overtimeMinutes)}',
              ),
              const SizedBox(height: 16),
              AppFormField(
                controller: controller,
                labelText: 'المبلغ المستحق',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الوقت الإضافي',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingOvertime.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد سجلات وقت إضافي تحتاج إلى متابعة.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingOvertime.length,
                        itemBuilder: (context, index) {
                          final record = _pendingOvertime[index];
                          final employee = _employees[record.employeeId];
                          final processing = _processingId == record.id;
                          return _OvertimeCard(
                            record: record,
                            employee: employee,
                            processing: processing,
                            onApprove: () =>
                                _confirmStatusChange(record, 'approved'),
                            onReject: () =>
                                _confirmStatusChange(record, 'rejected'),
                            onPay: employee != null &&
                                    record.approvalStatus == 'approved' &&
                                    record.paymentStatus != 'paid'
                                ? () => _showPayDialog(record, employee)
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  final OvertimeRecordModel record;
  final ProfileModel? employee;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onPay;

  const _OvertimeCard({
    required this.record,
    required this.employee,
    required this.processing,
    required this.onApprove,
    required this.onReject,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final employeeName = employee?.fullName ?? 'موظف غير معروف';
    final metadata = <String>[
      if (employee != null) employee!.employeeNumber,
      if (employee?.departmentName?.trim().isNotEmpty == true)
        employee!.departmentName!.trim(),
    ].join(' • ');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(employeeName.isEmpty ? 'م' : employeeName[0]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (metadata.isNotEmpty)
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _approvalStatus(record.approvalStatus),
            ],
          ),
          const Divider(height: 22),
          _InfoRow('تاريخ العمل', Formatters.date(record.workDate)),
          _InfoRow('نهاية الوردية', Formatters.time(record.shiftEnd)),
          _InfoRow('الخروج الفعلي', Formatters.time(record.actualCheckOut)),
          _InfoRow(
            'الوقت الإضافي',
            Formatters.minutesToHours(record.overtimeMinutes),
          ),
          if (record.overtimeAmount != null)
            _InfoRow('المبلغ', Formatters.money(record.overtimeAmount!)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('حالة الدفع: '),
              _paymentStatus(record.paymentStatus),
            ],
          ),
          const SizedBox(height: 14),
          if (record.approvalStatus == 'pending')
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: processing ? null : onApprove,
                    icon: processing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('اعتماد'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: processing ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
          if (onPay != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onPay,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('تسجيل دفع الوقت الإضافي'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _approvalStatus(String status) {
    return switch (status) {
      'approved' => AppStatusPill.success('معتمد'),
      'rejected' => AppStatusPill.danger('مرفوض'),
      _ => AppStatusPill.warning('بانتظار الاعتماد'),
    };
  }

  Widget _paymentStatus(String status) {
    return status == 'paid'
        ? AppStatusPill.success('مدفوع')
        : AppStatusPill.neutral('غير مدفوع');
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
