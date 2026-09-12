import 'package:flutter/material.dart';

import '../../models/fund_model.dart';
import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/fund_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManageAdvancesScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const ManageAdvancesScreen({super.key, required this.currentProfile});

  @override
  State<ManageAdvancesScreen> createState() => _ManageAdvancesScreenState();
}

class _ManageAdvancesScreenState extends State<ManageAdvancesScreen> {
  final _service = AdminService();
  bool _loading = true;
  List<dynamic> _advances = [];
  Map<String, ProfileModel> _employeesById = {};

  bool get _canManage => AppRoles.canManageAdvances(widget.currentProfile.role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _service.getPendingAdvances(),
        _service.getEmployees(limit: 500),
      ]);
      if (!mounted) return;
      final employees = results[1] as List<ProfileModel>;
      setState(() {
        _advances = results[0] as List<dynamic>;
        _employeesById = {
          for (final employee in employees) employee.id: employee,
        };
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل طلبات السلف: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(
    String id,
    String companyId,
    String employeeId,
    String status,
    double amount, {
    FundModel? fund,
  }) async {
    if (!_canManage) return;
    try {
      await _service.updateAdvanceStatus(
        advanceId: id,
        companyId: companyId,
        employeeId: employeeId,
        status: status,
      );

      if (status == 'approved' && fund != null) {
        final employee = _employeesById[employeeId];
        await FundService().addTransaction(
          fundId: fund.id,
          type: 'out',
          amount: amount,
          description:
              'صرف سلفة للموظف ${employee?.fullName ?? employeeId}',
          createdBy: widget.currentProfile.id,
          referenceId: id,
        );
      }

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'تم اعتماد السلفة وتسجيل عملية الصرف.'
                  : 'تم رفض طلب السلفة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث السلفة: $error')),
        );
      }
    }
  }

  Future<void> _approveWithFund(
    String advanceId,
    String companyId,
    String employeeId,
    double amount,
  ) async {
    if (!_canManage) return;
    final funds = await FundService().getFunds();
    if (!mounted) return;
    if (funds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد صناديق متاحة. أنشئ صندوقًا قبل اعتماد السلفة.'),
        ),
      );
      return;
    }

    FundModel? selectedFund;
    final employee = _employeesById[employeeId];
    final confirm = await AppFormDialog.show<bool>(
      context,
      title: 'اعتماد وصرف السلفة',
      submitText: 'اعتماد وصرف',
      builder: (context, setDialogState) {
        final scheme = Theme.of(context).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(12),
              backgroundColor: scheme.surfaceContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee?.fullName ?? employeeId,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'قيمة السلفة: ${Formatters.money(amount)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppDropdownField<FundModel>(
              labelText: 'الصندوق الذي سيتم الصرف منه',
              value: selectedFund,
              items: funds
                  .map(
                    (fund) => DropdownMenuItem(
                      value: fund,
                      child: Text(fund.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => selectedFund = value),
            ),
          ],
        );
      },
      onSubmit: () async => selectedFund != null,
    );

    if (confirm == true && selectedFund != null) {
      await _updateStatus(
        advanceId,
        companyId,
        employeeId,
        'approved',
        amount,
        fund: selectedFund,
      );
    }
  }

  Future<void> _reject(
    String id,
    String companyId,
    String employeeId,
    double amount,
  ) async {
    final employeeName = _employeesById[employeeId]?.fullName ?? employeeId;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'رفض طلب السلفة',
      content: 'هل تريد رفض طلب السلفة للموظف $employeeName؟',
      confirmText: 'رفض الطلب',
      isDestructive: true,
    );
    if (confirmed != true) return;
    await _updateStatus(id, companyId, employeeId, 'rejected', amount);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مراجعة السلف',
      body: _loading
          ? const AppLoadingState(label: 'جاري تحميل الطلبات')
          : !_canManage
              ? const AppEmptyState(
                  title: 'لا توجد صلاحية للإدارة',
                  message: 'يمكنك استخدام التقارير للاطلاع على بيانات السلف.',
                  icon: Icons.lock_outline,
                )
              : _advances.isEmpty
                  ? const AppEmptyState(
                      title: 'لا توجد طلبات سلف',
                      message: 'لا توجد سلف قيد المراجعة في الوقت الحالي.',
                      icon: Icons.account_balance_wallet_outlined,
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _advances.length,
                          itemBuilder: (context, index) {
                            final item = _advances[index];
                            final data = item.data;
                            final employeeId =
                                data['employee_id']?.toString() ?? '';
                            final employee = _employeesById[employeeId];
                            final employeeName =
                                employee?.fullName ?? 'موظف غير معروف';
                            final employeeMeta = <String>[
                              if (employee != null) employee.employeeNumber,
                              if (employee?.departmentName?.trim().isNotEmpty ==
                                  true)
                                employee!.departmentName!.trim(),
                            ].join(' • ');
                            final amount =
                                (data['principal_amount'] ?? 0).toDouble();

                            return _AdvanceReviewCard(
                              employeeName: employeeName,
                              employeeMeta: employeeMeta,
                              amount: amount,
                              requestDate: DateTime.parse(data['created_at']),
                              installmentAmount: data['installment_amount'],
                              reason: data['reason']?.toString(),
                              onApprove: () => _approveWithFund(
                                item.$id,
                                data['company_id'],
                                employeeId,
                                amount,
                              ),
                              onReject: () => _reject(
                                item.$id,
                                data['company_id'],
                                employeeId,
                                amount,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _AdvanceReviewCard extends StatelessWidget {
  final String employeeName;
  final String employeeMeta;
  final double amount;
  final DateTime requestDate;
  final dynamic installmentAmount;
  final String? reason;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AdvanceReviewCard({
    required this.employeeName,
    required this.employeeMeta,
    required this.amount,
    required this.requestDate,
    required this.installmentAmount,
    required this.reason,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(employeeName.isEmpty ? 'م' : employeeName[0]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (employeeMeta.isNotEmpty)
                      Text(
                        employeeMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppStatusPill.warning('قيد المراجعة'),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'قيمة السلفة',
                  value: Formatters.money(amount),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoTile(
                  label: 'تاريخ الطلب',
                  value: Formatters.date(requestDate),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
          if (installmentAmount != null) ...[
            const SizedBox(height: 8),
            _InfoTile(
              label: 'القسط المقترح',
              value: Formatters.money(installmentAmount),
              icon: Icons.payments_outlined,
            ),
          ],
          if (reason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('اعتماد وصرف'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: .55)),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
