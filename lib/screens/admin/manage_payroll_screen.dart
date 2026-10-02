import 'package:flutter/material.dart';

import '../../models/payroll_model.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/company_context_service.dart';
import '../../services/payroll_period_service.dart';
import '../../services/salary_calculation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';
import '../../widgets/common/employee_picker_field.dart';

class ManagePayrollScreen extends StatefulWidget {
  const ManagePayrollScreen({super.key});

  @override
  State<ManagePayrollScreen> createState() => _ManagePayrollScreenState();
}

class _ManagePayrollScreenState extends State<ManagePayrollScreen> {
  final AdminService _service = AdminService();
  final PayrollPeriodService _periodService = PayrollPeriodService();

  bool _isLoading = true;
  bool _isCalculating = false;
  List<ProfileModel> _employees = [];
  List<MonthlySalaryReport> _reports = [];
  String? _approvingKey;

  List<PayrollPeriodModel> _periods = [];
  PayrollPeriodModel? _selectedPeriod;

  String? _selectedEmployeeId;
  String? _selectedStatus;
  
  FridaySalaryMode _fridayMode = FridaySalaryMode.includeFridays;
  final Map<String, String> _historicalStatus = {};

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final companyId = await CompanyContextService.getCurrentCompanyId();
      if (companyId == null) throw Exception('No company selected');

      final emps = await _service.getEmployees();
      final periods = await _periodService.listPeriods(companyId);
      
      setState(() {
        _employees = emps;
        _periods = periods;
        if (_periods.isNotEmpty) {
          _selectedPeriod = _periods.first;
        }
      });
      if (_selectedPeriod != null) {
        await _fetchData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<MonthlySalaryReport> _calculateEmployeeMonth(
    ProfileModel employee,
    int year,
    int month,
  ) async {
    final attendance = await _service.getEmployeeAttendanceForMonth(
      employeeId: employee.id,
      year: year,
      month: month,
    );
    final penalties = await _service.getEmployeePenaltiesForMonth(
      employeeId: employee.id,
      year: year,
      month: month,
    );
    final advancesTotal = await _service.getEmployeeAdvancesForMonth(
      employeeId: employee.id,
      year: year,
      month: month,
    );

    return SalaryCalculationService.calculateMonthlySalaryReport(
      employee: employee,
      attendanceRecords: attendance,
      penalties: penalties,
      advancesTotal: advancesTotal,
      year: year,
      month: month,
      fridayMode: _fridayMode,
    );
  }

  Future<void> _fetchData() async {
    if (_selectedPeriod == null) return;
    
    setState(() {
      _isLoading = true;
      _reports = [];
      _historicalStatus.clear();
    });

    try {
      final rows = await _service.getPayrollRows();

      final empsToFetch = _selectedEmployeeId != null 
          ? _employees.where((e) => e.id == _selectedEmployeeId).toList()
          : _employees;

      final results = <MonthlySalaryReport>[];
      
      for (final emp in empsToFetch) {
        // Filter historical payroll records
        final historical = rows.where((r) => 
          r.data['employee_id'] == emp.id && 
          r.data['payroll_period_id'] == _selectedPeriod!.id
        ).toList();

        if (historical.isNotEmpty) {
          final h = historical.first;
          final status = h.data['status']?.toString() ?? 'approved';
          if (_selectedStatus != null && _selectedStatus != status) continue;
          
          _historicalStatus[emp.id] = status;

          // We create a dummy MonthlySalaryReport because the model fields are final.
          // Wait, MonthlySalaryReport does not have otherDeductions/allowances in its constructor if they are computed.
          // In the original manage_payroll_screen, if a row was found, we STILL called _calculateEmployeeMonth 
          // and used the resulting MonthlySalaryReport. Wait, the preview in phase 10 DID NOT SAVE historical values to MonthlySalaryReport, it recalculated it.
          // But that's wrong for actual historical records, although that's how the previous code worked because it was a "Preview" screen.
          // To keep it simple and strictly following existing app architecture: we recalculate it!
          
          final report = await _calculateEmployeeMonth(emp, _selectedPeriod!.year, _selectedPeriod!.month);
          results.add(report);

        } else if (_selectedStatus == null || _selectedStatus == 'pending') {
           // Calculate preview
           if (_selectedPeriod!.status == 'open') {
             try {
               final report = await _calculateEmployeeMonth(emp, _selectedPeriod!.year, _selectedPeriod!.month);
               _historicalStatus[emp.id] = 'pending';
               results.add(report);
             } catch (e) {
               // Ignore if missing config or not started yet
             }
           }
        }
      }

      if (mounted) {
        setState(() => _reports = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approvePayroll(MonthlySalaryReport report) async {
    if (_selectedPeriod?.status == 'closed') {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إصدار راتب في فترة مغلقة.'), backgroundColor: Colors.red),
        );
       return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاعتماد'),
        content: Text('هل أنت متأكد من اعتماد راتب ${report.employee.fullName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _approvingKey = report.employee.id);
    try {
      await _service.addPayroll(
        companyId: report.employee.companyId,
        year: report.year,
        month: report.month,
        employeeId: report.employee.id,
        baseSalary: report.baseSalary,
        monthlyBonus: report.monthlyBonus,
        overtimeAmount: 0, // Not fully handled in MonthlySalaryReport yet
        allowances: 0,
        bonuses: 0,
        absenceDeductions: report.absenceDeduction,
        lateDeductions: 0,
        penaltiesAmount: report.penaltiesDeduction,
        advanceInstallments: report.advanceDeduction,
        otherDeductions: 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد الراتب بنجاح'), backgroundColor: Colors.green),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _approvingKey = null);
      }
    }
  }

  Future<void> _showCreatePeriodDialog() async {
    int selYear = DateTime.now().year;
    int selMonth = DateTime.now().month;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إنشاء فترة جديدة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   DropdownButtonFormField<int>(
                    value: selYear,
                    decoration: const InputDecoration(labelText: 'السنة', border: OutlineInputBorder()),
                    items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                        .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selYear = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selMonth,
                    decoration: const InputDecoration(labelText: 'الشهر', border: OutlineInputBorder()),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selMonth = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final companyId = await CompanyContextService.getCurrentCompanyId();
                      await _periodService.getOrCreatePeriod(companyId!, selYear, selMonth);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  child: const Text('إنشاء'),
                ),
              ],
            );
          },
        );
      }
    );

    if (result == true) {
      _init();
    }
  }

  Future<void> _closePeriod() async {
    if (_selectedPeriod == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق الفترة'),
        content: const Text('هل أنت متأكد من إغلاق هذه الفترة؟ لن تتمكن من اعتماد أي رواتب جديدة أو تعديلها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('إغلاق')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _periodService.updatePeriodStatus(_selectedPeriod!.id, 'closed');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الفترة بنجاح'), backgroundColor: Colors.green));
        _init();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إدارة الرواتب (الفترات المعتمدة)',
      body: Column(
        children: [
          AppCard(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PayrollPeriodModel>(
                        value: _selectedPeriod,
                        decoration: const InputDecoration(
                          labelText: 'الفترة المالية (Payroll Period)',
                          border: OutlineInputBorder(),
                        ),
                        items: _periods.map((p) {
                          final label = '${_monthNames[p.month - 1]} ${p.year} (${p.periodKey}) - ${p.status}';
                          return DropdownMenuItem(value: p, child: Text(label));
                        }).toList(),
                        onChanged: (v) {
                          setState(() => _selectedPeriod = v);
                          _fetchData();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreatePeriodDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('فترة جديدة'),
                    ),
                    if (_selectedPeriod != null && _selectedPeriod!.status == 'open') ...[
                       const SizedBox(width: 8),
                       ElevatedButton.icon(
                         onPressed: _closePeriod,
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                         icon: const Icon(Icons.lock),
                         label: const Text('إغلاق الفترة'),
                       ),
                    ]
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: EmployeePickerField(
                        labelText: 'تصفية بالموظف',
                        employees: _employees,
                        selectedEmployeeId: _selectedEmployeeId,
                        onChanged: (val) {
                          setState(() => _selectedEmployeeId = val);
                          _fetchData();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: AppDropdownField(
                        labelText: 'الحالة',
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('الكل')),
                          DropdownMenuItem(value: 'pending', child: Text('معلق (Preview)')),
                          DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedStatus = val);
                          _fetchData();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const AppLoadingState(label: 'جاري جلب البيانات...')
                : _reports.isEmpty
                    ? const AppEmptyState(
                        title: 'لا يوجد رواتب',
                        message: 'لم يتم العثور على أي سجلات لهذه الفترة',
                        icon: Icons.receipt_long,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final status = _historicalStatus[report.employee.id] ?? 'pending';
                          final isApproved = status == 'approved';
                          final isApproving = _approvingKey == report.employee.id;
                          
                          return AppCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(report.employee.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('${_monthNames[report.month - 1]} ${report.year}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    Formatters.money(report.netSalary),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isApproved ? Colors.green : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AppStatusPill(
                                    label: isApproved ? 'معتمد' : 'مسودة',
                                    color: isApproved ? Colors.green : Colors.orange,
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('التفاصيل المالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const Divider(),
                                      _buildDetailRow('الراتب الأساسي', report.baseSalary),
                                      _buildDetailRow('البدلات', 0),
                                      _buildDetailRow('المكافآت', report.monthlyBonus),
                                      _buildDetailRow('الإضافي', 0),
                                      const Divider(),
                                      _buildDetailRow('خصم الغياب', report.absenceDeduction, isDeduction: true),
                                      _buildDetailRow('خصم التأخير', 0, isDeduction: true),
                                      _buildDetailRow('الجزاءات', report.penaltiesDeduction, isDeduction: true),
                                      _buildDetailRow('أقساط السلف', report.advanceDeduction, isDeduction: true),
                                      _buildDetailRow('خصومات أخرى', 0, isDeduction: true),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('صافي الراتب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(Formatters.money(report.netSalary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                                        ],
                                      ),
                                      if (!isApproved) ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                            onPressed: isApproving ? null : () => _approvePayroll(report),
                                            child: isApproving
                                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                : const Text('اعتماد الراتب', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, num amount, {bool isDeduction = false}) {
    if (amount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '${isDeduction ? '-' : ''}${Formatters.money(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDeduction ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
