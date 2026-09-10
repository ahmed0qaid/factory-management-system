import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../utils/formatters.dart';
import '../../services/fund_service.dart';
import '../../models/fund_model.dart';
import '../../models/profile_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_list_item.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getPendingAdvances();
      if (mounted) setState(() => _advances = items);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    try {
      await _service.updateAdvanceStatus(
        advanceId: id,
        companyId: companyId,
        employeeId: employeeId,
        status: status,
      );

      if (status == 'approved' && fund != null) {
        await FundService().addTransaction(
          fundId: fund.id,
          type: 'out',
          amount: amount,
          description: 'صرف سلفة للموظف رقم $employeeId',
          createdBy: widget.currentProfile.id,
          referenceId: id,
        );
      }

      _load();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة السلفة بنجاح.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveWithFund(String advanceId, String companyId, String employeeId, double amount) async {
    final funds = await FundService().getFunds();
    if (funds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد صناديق متاحة، يرجى إنشاء صندوق أولاً')),
        );
      }
      return;
    }

    FundModel? selectedFund;
    final confirm = await AppFormDialog.show<bool>(
      context,
      title: 'اعتماد السلفة',
      submitText: 'اعتماد وصرف',
      builder: (context, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الرجاء اختيار الصندوق الذي سيتم صرف السلفة منه:'),
            const SizedBox(height: 16),
            AppDropdownField<FundModel>(
              labelText: 'الصندوق',
              value: selectedFund,
              items: funds.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(),
              onChanged: (val) => setDialogState(() => selectedFund = val),
            ),
          ],
        );
      },
      onSubmit: () async {
        return selectedFund != null;
      },
    );

    if (confirm == true && selectedFund != null) {
      await _updateStatus(advanceId, companyId, employeeId, 'approved', amount, fund: selectedFund);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مراجعة السلف',
      body: _loading
          ? const AppLoadingState(label: 'جاري تحميل الطلبات')
          : _advances.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد طلبات سلف',
              message: 'لا توجد سلف قيد المراجعة في الوقت الحالي.',
              icon: Icons.account_balance_wallet_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _advances.length,
              itemBuilder: (context, index) {
                final item = _advances[index];
                final data = item.data;
                return AppListItem(
                  title: Text(
                    'طلب سلفة بـ ${Formatters.money(data['principal_amount'])}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تاريخ الطلب: ${Formatters.date(DateTime.parse(data['created_at']))}',
                      ),
                      if (data['reason'] != null &&
                          data['reason'].toString().isNotEmpty)
                        Text('السبب: ${data['reason']}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: AppColors.success),
                        onPressed: () => _approveWithFund(
                          item.$id,
                          data['company_id'],
                          data['employee_id'],
                          (data['principal_amount'] ?? 0).toDouble(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.danger),
                        onPressed: () => _updateStatus(
                          item.$id,
                          data['company_id'],
                          data['employee_id'],
                          'rejected',
                          (data['principal_amount'] ?? 0).toDouble(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
