import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/salary_calculation_service.dart';
import '../../utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManagePayrollScreen extends StatefulWidget {
  const ManagePayrollScreen({super.key});

  @override
  State<ManagePayrollScreen> createState() => _ManagePayrollScreenState();
}

class _ManagePayrollScreenState extends State<ManagePayrollScreen> {
  final AdminService _service = AdminService();
  bool _isLoading = true;
  bool _isCalculating = false;
  List<ProfileModel> _employees = [];
  List<MonthlySalaryReport> _reports = [];
  ProfileModel? _selectedEmployeeForApproval;
  MonthlySalaryReport? _selectedReportForApproval;

  int? _selectedYear;
  int? _pendingYear;
  int? _selectedMonth;
  int? _pendingMonth;
  String? _selectedEmployeeId;
  String? _pendingEmployeeId;
  String? _selectedStatus;
  String? _pendingStatus;
  List<int> _availableYears = [];
  FridaySalaryMode _fridayMode = FridaySalaryMode.includeFridays;
  FridaySalaryMode _pendingFridayMode = FridaySalaryMode.includeFridays;
  final Map<String, String> _payrollStatusesByMonth = {};

  static const _monthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _service.getEmployees(limit: 500);
      final payrollRows = await _service.getPayrollRows(limit: 500);
      final attendanceRows = await _service.getAttendanceRows(limit: 1000);
      final years = <int>{DateTime.now().year};

      for (final row in payrollRows) {
        final data = row.data;
        final date = DateTime.tryParse(
          (data['created_at'] ?? data['start_date'] ?? '').toString(),
        );
        if (date != null) {
          years.add(date.year);
          final employeeId = data['employee_id']?.toString();
          if (employeeId != null && employeeId.isNotEmpty) {
            _payrollStatusesByMonth[_reportKey(
                  employeeId,
                  date.year,
                  date.month,
                )] =
                data['status']?.toString() ?? '';
          }
        }
      }

      for (final row in attendanceRows) {
        final date = DateTime.tryParse(row.data['work_date']?.toString() ?? '');
        if (date != null) years.add(date.year);
      }

      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _employees = employees.where((e) => e.active).toList();
          _availableYears = years.toList()..sort((a, b) => b.compareTo(a));
          _selectedYear = now.year;
          _pendingYear = _selectedYear;
          _selectedMonth = now.month;
          _pendingMonth = _selectedMonth;
        });
      }
      await _calculateReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب بيانات الرواتب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateReports() async {
    final years = _selectedYear == null
        ? (_availableYears.isEmpty ? [DateTime.now().year] : _availableYears)
        : [_selectedYear!];
    final months = _selectedMonth == null
        ? List<int>.generate(12, (index) => index + 1)
        : [_selectedMonth!];
    final employees = _selectedEmployeeId == null
        ? _employees
        : _employees.where((e) => e.id == _selectedEmployeeId).toList();

    setState(() {
      _isCalculating = true;
      _selectedEmployeeForApproval = null;
      _selectedReportForApproval = null;
    });

    try {
      final reports = <MonthlySalaryReport>[];
      for (final year in years) {
        for (final month in months) {
          for (final employee in employees) {
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
            final report =
                SalaryCalculationService.calculateMonthlySalaryReport(
                  employee: employee,
                  attendanceRecords: attendance,
                  penalties: penalties,
                  advancesTotal: advancesTotal,
                  year: year,
                  month: month,
                  fridayMode: _fridayMode,
                );
            if (_selectedStatus == null ||
                _statusForReport(report) == _selectedStatus) {
              reports.add(report);
            }
          }
        }
      }

      reports.sort((a, b) {
        final byDate = b.monthKey.compareTo(a.monthKey);
        if (byDate != 0) return byDate;
        return a.employee.fullName.compareTo(b.employee.fullName);
      });

      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في حساب التقرير: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _approvePayroll(MonthlySalaryReport report) async {
    setState(() {
      _isCalculating = true;
      _selectedEmployeeForApproval = report.employee;
      _selectedReportForApproval = report;
    });
    try {
      await _service.addPayroll(
        companyId: report.employee.companyId,
        employeeId: report.employee.id,
        baseSalary: report.baseSalary,
        monthlyBonus: report.monthlyBonus,
        overtimeAmount: 0,
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
          const SnackBar(content: Text('تم اعتماد الراتب بنجاح!')),
        );
        await _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
          _selectedEmployeeForApproval = null;
          _selectedReportForApproval = null;
        });
      }
    }
  }

  void _showFiltersSheet() {
    _pendingYear = _selectedYear;
    _pendingMonth = _selectedMonth;
    _pendingEmployeeId = _selectedEmployeeId;
    _pendingStatus = _selectedStatus;
    _pendingFridayMode = _fridayMode;

    AppBottomSheet.show(
      context,
      title: 'الفلاتر',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filterDropdown<int>(
                label: 'السنة',
                value: _pendingYear,
                allLabel: 'الكل',
                items: _availableYears,
                itemLabel: (year) => year.toString(),
                onChanged: (value) =>
                    setSheetState(() => _pendingYear = value),
              ),
              const SizedBox(height: 12),
              _filterDropdown<int>(
                label: 'الشهر',
                value: _pendingMonth,
                allLabel: 'الكل',
                items: List<int>.generate(12, (index) => index + 1),
                itemLabel: (month) => _monthNames[month - 1],
                onChanged: (value) =>
                    setSheetState(() => _pendingMonth = value),
              ),
              const SizedBox(height: 12),
              _filterDropdown<String>(
                label: 'الموظف',
                value: _pendingEmployeeId,
                allLabel: 'الكل',
                items: _employees.map((e) => e.id).toList(),
                itemLabel: (id) {
                  final employee = _employees.firstWhere(
                    (e) => e.id == id,
                  );
                  return '${employee.fullName} (${employee.employeeNumber})';
                },
                onChanged: (value) =>
                    setSheetState(() => _pendingEmployeeId = value),
              ),
              const SizedBox(height: 12),
              _filterDropdown<String>(
                label: 'الحالة',
                value: _pendingStatus,
                allLabel: 'الكل',
                items: const ['approved', 'draft', 'pending'],
                itemLabel: _statusLabel,
                onChanged: (value) =>
                    setSheetState(() => _pendingStatus = value),
              ),
              const SizedBox(height: 12),
              AppDropdownField<FridaySalaryMode>(
                labelText: 'طريقة احتساب أيام الجمعة',
                value: _pendingFridayMode,
                items: FridaySalaryMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => _pendingFridayMode = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = DateTime.now().year;
                          _selectedMonth = DateTime.now().month;
                          _selectedEmployeeId = null;
                          _selectedStatus = null;
                          _fridayMode = FridaySalaryMode.includeFridays;
                        });
                        Navigator.pop(context);
                        _calculateReports();
                      },
                      child: const Text('إعادة تعيين'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = _pendingYear;
                          _selectedMonth = _pendingMonth;
                          _selectedEmployeeId = _pendingEmployeeId;
                          _selectedStatus = _pendingStatus;
                          _fridayMode = _pendingFridayMode;
                        });
                        Navigator.pop(context);
                        _calculateReports();
                      },
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required String allLabel,
    required List<T> items,
    required String Function(T item) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return AppDropdownField<T?>(
      labelText: label,
      value: value,
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
        ...items.map(
          (item) => DropdownMenuItem<T?>(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تقرير الرواتب الشهري',
      actions: [
        IconButton(
          tooltip: 'الفلاتر',
          icon: const Icon(Icons.tune),
          onPressed: _isLoading ? null : _showFiltersSheet,
        ),
      ],
      body: _isLoading
          ? const AppLoadingState(label: 'جاري تحميل الرواتب')
          : RefreshIndicator(
              onRefresh: _calculateReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryHeader(),
                  const SizedBox(height: 16),
                  if (_isCalculating)
                    const LinearProgressIndicator(minHeight: 3, color: AppColors.primary),
                  if (_reports.isEmpty)
                    const AppEmptyState(
                      title: 'لا توجد تقارير',
                      message: 'لا توجد تقارير رواتب مطابقة للفلاتر المحددة.',
                      icon: Icons.payments_outlined,
                    )
                  else
                    ..._groupedReports().entries.map(_monthSection),
                ],
              ),
            ),
    );
  }

  Widget _summaryHeader() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _showFiltersSheet,
          icon: const Icon(Icons.tune),
          label: const Text('الفلاتر'),
        ),
        Chip(label: Text('السنة: ${_selectedYear?.toString() ?? 'الكل'}')),
        Chip(
          label: Text(
            'الشهر: ${_selectedMonth == null ? 'الكل' : _monthNames[_selectedMonth! - 1]}',
          ),
        ),
        Chip(label: Text('الموظف: ${_employeeFilterLabel()}')),
        Chip(label: Text('الحالة: ${_statusLabel(_selectedStatus)}')),
        Chip(label: Text(_fridayMode.label)),
      ],
    );
  }

  Map<String, List<MonthlySalaryReport>> _groupedReports() {
    final grouped = <String, List<MonthlySalaryReport>>{};
    for (final report in _reports) {
      grouped.putIfAbsent(report.monthKey, () => []).add(report);
    }
    return grouped;
  }

  Widget _monthSection(MapEntry<String, List<MonthlySalaryReport>> entry) {
    final first = entry.value.first;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Text(
              '${_monthNames[first.month - 1]} ${first.year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('اسم الموظف')),
                  DataColumn(label: Text('رقم الموظف')),
                  DataColumn(label: Text('الشهر والسنة')),
                  DataColumn(label: Text('الراتب الأساسي')),
                  DataColumn(label: Text('المكافأة الشهرية')),
                  DataColumn(label: Text('الاستحقاق الكلي')),
                  DataColumn(label: Text('طريقة احتساب الجمعة')),
                  DataColumn(label: Text('عدد أيام الشهر')),
                  DataColumn(label: Text('عدد أيام الجمعة')),
                  DataColumn(label: Text('أيام الراتب المعتمدة')),
                  DataColumn(label: Text('أجر اليوم')),
                  DataColumn(label: Text('ساعات العمل اليومية')),
                  DataColumn(label: Text('أجر الساعة')),
                  DataColumn(label: Text('أيام الحضور')),
                  DataColumn(label: Text('أيام الغياب')),
                  DataColumn(label: Text('راتب الحضور')),
                  DataColumn(label: Text('خصم الغياب')),
                  DataColumn(label: Text('خصم الجزاءات')),
                  DataColumn(label: Text('خصم السلف')),
                  DataColumn(label: Text('صافي الراتب')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('إجراءات')),
                ],
                rows: entry.value.map(_reportRow).toList(),
              ),
            ),
          ],
        ),
    );
  }

  DataRow _reportRow(MonthlySalaryReport report) {
    final approving =
        _selectedEmployeeForApproval?.id == report.employee.id &&
        _selectedReportForApproval?.monthKey == report.monthKey &&
        _isCalculating;
    return DataRow(
      cells: [
        DataCell(Text(report.employee.fullName)),
        DataCell(Text(report.employee.employeeNumber)),
        DataCell(Text('${_monthNames[report.month - 1]} ${report.year}')),
        DataCell(Text(Formatters.money(report.baseSalary))),
        DataCell(Text(Formatters.money(report.monthlyBonus))),
        DataCell(Text(Formatters.money(report.grossSalary))),
        DataCell(Text(report.fridayMode.label)),
        DataCell(Text(report.daysInMonth.toString())),
        DataCell(Text(report.fridaysCount.toString())),
        DataCell(Text(report.salaryDays.toString())),
        DataCell(Text(Formatters.money(report.dailyWage))),
        DataCell(Text(report.dailyWorkHours.toString())),
        DataCell(Text(Formatters.money(report.hourlyWage))),
        DataCell(Text(report.presentDays.toString())),
        DataCell(Text(report.absentDays.toString())),
        DataCell(Text(Formatters.money(report.attendanceSalary))),
        DataCell(Text('-${Formatters.money(report.absenceDeduction)}')),
        DataCell(Text('-${Formatters.money(report.penaltiesDeduction)}')),
        DataCell(Text('-${Formatters.money(report.advanceDeduction)}')),
        DataCell(Text(Formatters.money(report.netSalary))),
        DataCell(AppStatusPill(
          color: _statusColor(_statusForReport(report)),
          label: _statusLabel(_statusForReport(report)),
        )),
        DataCell(
          TextButton.icon(
            onPressed: approving ? null : () => _approvePayroll(report),
            icon: approving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('اعتماد'),
          ),
        ),
      ],
    );
  }

  String _reportKey(String employeeId, int year, int month) {
    return '$employeeId-$year-${month.toString().padLeft(2, "0")}';
  }

  String? _statusForReport(MonthlySalaryReport report) {
    return _payrollStatusesByMonth[_reportKey(
      report.employee.id,
      report.year,
      report.month,
    )];
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'paid':
        return 'تم الصرف';
      case 'approved':
        return 'معتمد';
      default:
        return 'قيد المراجعة';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'approved':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  String _employeeFilterLabel() {
    if (_selectedEmployeeId == null) return 'الكل';
    final employee = _employees.firstWhere((e) => e.id == _selectedEmployeeId);
    return employee.fullName;
  }
}
