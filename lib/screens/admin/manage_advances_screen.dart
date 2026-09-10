import 'package:flutter/material.dart';

import '../../models/fund_model.dart';
import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/fund_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

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
        _employeesById = {for (final employee in employees) employee.id: employee};
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الموظف: ${employee?.fullName ?? employeeId}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text('قيمة السلفة: ${Formatters.money(amount)}'),
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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('رفض طلب السلفة'),
            content: Text('هل تريد رفض طلب السلفة للموظف $employeeName؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('رفض الطلب'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
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
                            final employeeId = data['employee_id']?.toString() ?? '';
                            final employee = _employeesById[employeeId];
                            final employeeName = employee?.fullName ?? 'موظف غير معروف';
                            final employeeMeta = <String>[
                              if (employee != null) employee.employeeNumber,
                              if (employee?.departmentName?.trim().isNotEmpty == true)
                                employee!.departmentName!.trim(),
                            ].join(' • ');
                            final amount =
                                (data['principal_amount'] ?? 0).toDouble();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          child: Text(
                                            employeeName.isEmpty ? 'م' : employeeName[0],
                                          ),
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                              if (employeeMeta.isNotEmpty)
                                                Text(
                                                  employeeMeta,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.account_balance_wallet_outlined),
                                      ],
                                    ),
                                    const Divider(height: 22),
                                    Text(
                                      'قيمة السلفة: ${Formatters.money(amount)}',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'تاريخ الطلب: ${Formatters.date(DateTime.parse(data['created_at']))}',
                                    ),
                                    if (data['installment_amount'] != null)
                                      Text(
                                        'القسط المقترح: ${Formatters.money(data['installment_amount'])}',
                                      ),
                                    if (data['reason'] != null &&
                                        data['reason'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text('السبب: ${data['reason']}'),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () => _approveWithFund(
                                              item.$id,
                                              data['company_id'],
                                              employeeId,
                                              amount,
                                            ),
                                            icon: const Icon(Icons.check),
                                            label: const Text('اعتماد وصرف'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _reject(
                                              item.$id,
                                              data['company_id'],
                                              employeeId,
                                              amount,
                                            ),
                                            icon: const Icon(Icons.close),
                                            label: const Text('رفض'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}
