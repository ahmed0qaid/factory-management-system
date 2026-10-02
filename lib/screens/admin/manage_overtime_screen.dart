import 'package:flutter/material.dart';

import '../../models/overtime_record_model.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/company_context_service.dart';
import '../../services/overtime_admin_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManageOvertimeScreen extends StatefulWidget {
  final String companyId;

  const ManageOvertimeScreen({super.key, required this.companyId});

  @override
  State<ManageOvertimeScreen> createState() => _ManageOvertimeScreenState();
}

class _ManageOvertimeScreenState extends State<ManageOvertimeScreen>
    with SingleTickerProviderStateMixin {
  final _overtimeService = OvertimeAdminService();
  final _adminService = AdminService();

  late TabController _tabController;

  bool _isLoading = true;
  String? _processingId;
  List<OvertimeRecordModel> _records = [];
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
      final recordsFuture = _overtimeService.getOvertimeRecords();
      final employeesFuture = _adminService.getEmployees(limit: 500);
      
      final records = await recordsFuture;
      final employees = await employeesFuture;
      
      if (!mounted) return;

      setState(() {
        _records = records;
        _employees = {for (final employee in employees) employee.id: employee};
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السجلات: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<OvertimeRecordModel> get _filteredRecords {
    String currentStatus = 'pending';
    bool wantPaid = false;
    
    switch (_tabController.index) {
      case 0:
        currentStatus = 'pending';
        break;
      case 1:
        currentStatus = 'approved';
        wantPaid = false;
        break;
      case 2:
        currentStatus = 'rejected';
        break;
      case 3:
        currentStatus = 'approved';
        wantPaid = true;
        break;
    }

    return _records.where((r) {
      if (currentStatus == 'pending' || currentStatus == 'rejected') {
        if (r.approvalStatus != currentStatus) return false;
      } else if (currentStatus == 'approved') {
        if (r.approvalStatus != 'approved') return false;
        if (wantPaid && r.paymentStatus != 'paid') return false;
        if (!wantPaid && r.paymentStatus == 'paid') return false;
      }

      if (_searchQuery.isNotEmpty) {
        final emp = _employees[r.employeeId];
        final name = emp?.fullName.toLowerCase() ?? '';
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _changeStatus(OvertimeRecordModel record, String newStatus) async {
    final employee = _employees[record.employeeId];
    final isApproving = newStatus == 'approved';
    
    final noteController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isApproving ? 'اعتماد العمل الإضافي' : 'رفض العمل الإضافي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الموظف: ${employee?.fullName ?? 'غير معروف'}'),
              Text('التاريخ: ${Formatters.date(record.workDate)}'),
              Text('الدقائق: ${record.overtimeMinutes} دقيقة'),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'الملاحظة (مطلوبة)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproving ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(isApproving ? 'اعتماد' : 'رفض'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (noteController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال ملاحظة')),
      );
      return;
    }

    setState(() => _processingId = record.id);
    try {
      await _overtimeService.updateOvertimeStatus(record.id, newStatus, noteController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isApproving ? 'تم الاعتماد بنجاح' : 'تم الرفض بنجاح')),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _payRecord(OvertimeRecordModel record) async {
    final employee = _employees[record.employeeId];
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'دفع العمل الإضافي',
      content: 'تأكيد دفع العمل الإضافي للموظف ${employee?.fullName ?? ''}؟',
      confirmText: 'دفع',
    );
    if (confirmed != true) return;

    setState(() => _processingId = record.id);
    try {
      await _overtimeService.payOvertime(record.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الدفع بنجاح')),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إدارة العمل الإضافي',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'قيد الانتظار'),
              Tab(text: 'معتمد (غير مدفوع)'),
              Tab(text: 'مرفوض'),
              Tab(text: 'مدفوع'),
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
                    ? const AppEmptyState(title: 'لا توجد سجلات', message: 'لا يوجد عمل إضافي مطابق للبحث')
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            final record = _filteredRecords[index];
                            final employee = _employees[record.employeeId];
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

  Widget _buildRecordCard(OvertimeRecordModel record, ProfileModel? employee, bool isProcessing) {
    final statusColor = record.approvalStatus == 'approved'
        ? Colors.green
        : record.approvalStatus == 'rejected'
            ? Colors.red
            : Colors.orange;

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
                Expanded(
                  child: Text(
                    employee?.fullName ?? 'موظف غير معروف',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                AppStatusPill(
                  label: record.paymentStatus == 'paid' ? 'مدفوع' : (record.approvalStatus == 'pending' ? 'قيد الانتظار' : (record.approvalStatus == 'approved' ? 'معتمد' : 'مرفوض')),
                  color: record.paymentStatus == 'paid' ? Colors.blue : statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('التاريخ: ${Formatters.date(record.workDate)}'),
            Text('نهاية الوردية المجدولة: ${Formatters.time(record.shiftEnd)}'),
            Text('وقت الانصراف الفعلي: ${Formatters.time(record.actualCheckOut)}'),
            Text('دقائق العمل الإضافي: ${record.overtimeMinutes} دقيقة (${(record.overtimeMinutes / 60).toStringAsFixed(1)} ساعة)', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (record.approvalNote != null) ...[
              const SizedBox(height: 8),
              Text('Note: ' + record.approvalNote.toString()),
            ],
            if (record.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text('Reason: ' + record.rejectionReason.toString(), style: const TextStyle(color: Colors.red)),
            ],
            
            if (record.approvalStatus == 'pending' && _tabController.index == 0) ...[
              const SizedBox(height: 16),
              if (isProcessing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _changeStatus(record, 'rejected'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('رفض'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _changeStatus(record, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('اعتماد'),
                    ),
                  ],
                ),
            ],
            
            if (record.approvalStatus == 'approved' && record.paymentStatus == 'unpaid' && _tabController.index == 1) ...[
              const SizedBox(height: 16),
              if (isProcessing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _payRecord(record),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('تأشير كمدفوع'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
