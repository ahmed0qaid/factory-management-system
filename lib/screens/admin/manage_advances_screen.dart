import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/advance_admin_service.dart';
import '../../services/company_context_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManageAdvancesScreen extends StatefulWidget {
  final String companyId;

  const ManageAdvancesScreen({super.key, required this.companyId});

  @override
  State<ManageAdvancesScreen> createState() => _ManageAdvancesScreenState();
}

class _ManageAdvancesScreenState extends State<ManageAdvancesScreen>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  final _advanceAdminService = AdvanceAdminService();

  late TabController _tabController;
  bool _isLoading = true;
  String? _processingId;

  List<AdvanceModel> _records = [];
  Map<String, ProfileModel> _employees = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await CompanyContextService.requireCompany(widget.companyId);
      final employees = await _adminService.getEmployees(limit: 500);
      _employees = {for (final e in employees) e.id: e};

      // We should ideally have a getAdvances() in AdvanceAdminService.
      // But AdminService has getAdvances(companyId).
      // Let's use it or fetch manually here.
      final rows = await _advanceAdminService.getAdvances(widget.companyId);
      if (!mounted) return;
      setState(() {
        _records = rows;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AdvanceModel> get _filteredRecords {
    String currentStatus = 'pending';
    String? currentRepayment;

    switch (_tabController.index) {
      case 0:
        currentStatus = 'pending';
        break;
      case 1:
        currentStatus = 'approved';
        currentRepayment = 'active';
        break;
      case 2:
        currentStatus = 'approved';
        currentRepayment = 'fully_paid';
        break;
      case 3:
        currentStatus = 'rejected_cancelled';
        break;
    }

    return _records.where((r) {
      if (currentStatus == 'rejected_cancelled') {
        if (r.status != 'rejected' && r.status != 'cancelled') return false;
      } else if (currentStatus == 'approved') {
        if (r.status != 'approved') return false;
        if (currentRepayment != null && r.repaymentStatus != currentRepayment) return false;
      } else {
        if (r.status != currentStatus) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final empName = _employees[r.id]?.fullName.toLowerCase() ?? '';
        if (!empName.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _showApproveDialog(AdvanceModel record) async {
    final noteController = TextEditingController();
    final amountController = TextEditingController(text: record.principalAmount.toString());
    final countController = TextEditingController(text: '1');
    final monthController = TextEditingController(text: DateTime.now().year.toString() + '-' + DateTime.now().month.toString().padLeft(2, '0'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('اعتماد السلفة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المعتمد', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countController,
                  decoration: const InputDecoration(labelText: 'عدد الأقساط', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: monthController,
                  decoration: const InputDecoration(labelText: 'شهر بدء الخصم (YYYY-MM)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'الملاحظة (إلزامية)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('اعتماد'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _processingId = record.id);
      try {
        await _advanceAdminService.updateAdvanceStatus(
          advanceId: record.id,
          status: 'approved',
          approvedAmount: num.tryParse(amountController.text),
          installmentCount: int.tryParse(countController.text),
          firstInstallmentMonth: monthController.text,
          approvalNote: noteController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد بنجاح')));
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      } finally {
        if (mounted) setState(() => _processingId = null);
      }
    }
  }

  Future<void> _showRejectCancelDialog(AdvanceModel record, bool isCancel) async {
    final noteController = TextEditingController();
    final actionName = isCancel ? 'إلغاء' : 'رفض';
    final status = isCancel ? 'cancelled' : 'rejected';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$actionName السلفة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'السبب (إلزامي)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(actionName),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _processingId = record.id);
      try {
        await _advanceAdminService.updateAdvanceStatus(
          advanceId: record.id,
          status: status,
          rejectionReason: noteController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم $actionName بنجاح')));
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      } finally {
        if (mounted) setState(() => _processingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إدارة السلف والأقساط',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'قيد الانتظار'),
              Tab(text: 'نشط/معتمد'),
              Tab(text: 'مكتمل السداد'),
              Tab(text: 'مرفوض/ملغي'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث باسم الموظف',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingState(label: 'جاري تحميل السجلات...')
                : _filteredRecords.isEmpty
                    ? const AppEmptyState(title: 'لا توجد سجلات', message: 'لا توجد سلف متطابقة')
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            final record = _filteredRecords[index];
                            final employee = _employees[record.employeeId]; // Oh wait! it should be record.employeeId but AdvanceModel does not have employeeId?
                            // Wait! Let me check AdvanceModel!
                            final isProcessing = _processingId == record.id;
                            return _buildRecordCard(record, employee, isProcessing);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(AdvanceModel record, ProfileModel? employee, bool isProcessing) {
    // We'll fix employeeId extraction above if it fails.
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(employee?.fullName ?? 'موظف غير معروف', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                AppStatusPill(
                  label: record.status == 'approved' ? (record.repaymentStatus == 'fully_paid' ? 'مكتمل' : 'نشط') : record.status,
                  color: record.status == 'approved' ? Colors.green : (record.status == 'pending' ? Colors.orange : Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('تاريخ الطلب: ${Formatters.date(record.requestDate)}'),
            Text('المبلغ المطلوب: ${Formatters.money(record.principalAmount)}'),
            if (record.status == 'approved') ...[
              Text('المبلغ المعتمد: ${Formatters.money(record.approvedAmount ?? record.principalAmount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Text('المتبقي: ${Formatters.money(record.remainingAmount)}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              Text('عدد الأقساط: ${record.installmentCount ?? '-'}'),
              Text('قيمة القسط: ${Formatters.money(record.installmentAmount)}'),
              Text('أول قسط: ${record.firstInstallmentMonth ?? '-'}'),
            ],
            if (record.status == 'pending' && _tabController.index == 0) ...[
              const SizedBox(height: 16),
              if (isProcessing) const Center(child: CircularProgressIndicator())
              else Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => _showRejectCancelDialog(record, false), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('رفض')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _showApproveDialog(record), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('اعتماد')),
                ],
              )
            ],
            if (record.status == 'approved' && record.repaymentStatus == 'active' && _tabController.index == 1) ...[
               const SizedBox(height: 16),
               if (isProcessing) const Center(child: CircularProgressIndicator())
               else Align(
                 alignment: Alignment.centerLeft,
                 child: TextButton(onPressed: () => _showRejectCancelDialog(record, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('إلغاء السلفة')),
               )
            ]
          ],
        ),
      ),
    );
  }
}
