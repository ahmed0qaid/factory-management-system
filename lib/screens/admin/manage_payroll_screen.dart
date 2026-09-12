import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/salary_calculation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_bottom_sheet.dart';
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

  bool _isLoading = true;
  bool _isCalculating = false;
  List<ProfileModel> _employees = [];
  List<MonthlySalaryReport> _reports = [];
  String? _approvingKey;

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
      final results = await Future.wait<dynamic>([
        _service.getEmployees(limit: 500),
        _service.getPayrollRows(limit: 1000),
        _service.getAttendanceRows(limit: 2000),
      ]);
      final employees = results[0] as List<ProfileModel>;
      final payrollRows = results[1] as List<dynamic>;
      final attendanceRows = results[2] as List<dynamic>;
      final years = <int>{DateTime.now().year};
      final statuses = <String, String>{};

      for (final row in payrollRows) {
        final data = row.data;
        final date = DateTime.tryParse(
          (data['created_at'] ?? data['start_date'] ?? '').toString(),
        );
        if (date == null) continue;
        years.add(date.year);
        final employeeId = data['employee_id']?.toString();
        if (employeeId == null || employeeId.isEmpty) continue;
        statuses[_reportKey(employeeId, date.year, date.month)] =
            data['status']?.toString() ?? 'approved';
      }

      for (final row in attendanceRows) {
        final date = DateTime.tryParse(row.data['work_date']?.toString() ?? '');
        if (date != null) years.add(date.year);
      }

      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _employees = employees.where((employee) => employee.active).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        _availableYears = years.toList()..sort((a, b) => b.compareTo(a));
        _payrollStatusesByMonth
          ..clear()
          ..addAll(statuses);
        _selectedYear = now.year;
        _pendingYear = now.year;
        _selectedMonth = now.month;
        _pendingMonth = now.month;
      });
      await _calculateReports();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل بيانات الرواتب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<MonthlySalaryReport> _calculateEmployeeMonth(
    ProfileModel employee,
    int year,
    int month,
  ) async {
    // Start independent backend reads together instead of waiting for each one
    // serially. This keeps the report responsive without flooding the backend.
    final attendanceFuture = _service.getEmployeeAttendanceForMonth(
      employeeId: employee.id,
      year: year,
      month: month,
    );
    final penaltiesFuture = _service.getEmployeePenaltiesForMonth(
      employeeId: employee.id,
      year: year,
      month: month,
    );
    final advancesFuture = _service.getEmployeeAdvancesForMonth(
      employeeId: employee.id,
      year: year,
      month: month,
    );

    final attendance = await attendanceFuture;
    final penalties = await penaltiesFuture;
    final advancesTotal = await advancesFuture;

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

  Future<void> _calculateReports() async {
    if (!mounted) return;
    final years = _selectedYear == null
        ? (_availableYears.isEmpty ? [DateTime.now().year] : _availableYears)
        : [_selectedYear!];
    final months = _selectedMonth == null
        ? List<int>.generate(12, (index) => index + 1)
        : [_selectedMonth!];
    final employees = _selectedEmployeeId == null
        ? _employees
        : _employees
              .where((employee) => employee.id == _selectedEmployeeId)
              .toList();

    setState(() {
      _isCalculating = true;
      _reports = [];
    });

    try {
      final reports = <MonthlySalaryReport>[];
      const concurrency = 8;

      for (final year in years) {
        for (final month in months) {
          for (var start = 0; start < employees.length; start += concurrency) {
            final end = (start + concurrency).clamp(0, employees.length);
            final chunk = employees.sublist(start, end);
            final calculated = await Future.wait(
              chunk.map(
                (employee) => _calculateEmployeeMonth(employee, year, month),
              ),
            );
            for (final report in calculated) {
              if (_selectedStatus == null ||
                  _statusForReport(report) == _selectedStatus) {
                reports.add(report);
              }
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حساب تقرير الرواتب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _approvePayroll(MonthlySalaryReport report) async {
    final status = _statusForReport(report);
    if (status == 'approved' || status == 'paid') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('هذا الراتب معتمد مسبقًا.')));
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('اعتماد الراتب'),
            content: Text(
              'اعتماد راتب ${report.employee.fullName} عن ${_monthNames[report.month - 1]} ${report.year}\n\nصافي الراتب: ${Formatters.money(report.netSalary)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('اعتماد'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final key = _reportKey(report.employee.id, report.year, report.month);
    setState(() => _approvingKey = key);
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
      if (!mounted) return;
      setState(() => _payrollStatusesByMonth[key] = 'approved');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم اعتماد راتب ${report.employee.fullName} بنجاح.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر اعتماد الراتب: $error')));
      }
    } finally {
      if (mounted) setState(() => _approvingKey = null);
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
      title: 'فلاتر تقرير الرواتب',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filterDropdown<int>(
                  label: 'السنة',
                  value: _pendingYear,
                  allLabel: 'كل السنوات',
                  items: _availableYears,
                  itemLabel: (year) => year.toString(),
                  onChanged: (value) =>
                      setSheetState(() => _pendingYear = value),
                ),
                const SizedBox(height: 12),
                _filterDropdown<int>(
                  label: 'الشهر',
                  value: _pendingMonth,
                  allLabel: 'كل الأشهر',
                  items: List<int>.generate(12, (index) => index + 1),
                  itemLabel: (month) => _monthNames[month - 1],
                  onChanged: (value) =>
                      setSheetState(() => _pendingMonth = value),
                ),
                const SizedBox(height: 12),
                EmployeePickerField(
                  employees: _employees,
                  selectedEmployeeId: _pendingEmployeeId,
                  allowAll: true,
                  allEmployeesLabel: 'كل الموظفين',
                  labelText: 'الموظف',
                  onChanged: (value) =>
                      setSheetState(() => _pendingEmployeeId = value),
                ),
                const SizedBox(height: 12),
                _filterDropdown<String>(
                  label: 'الحالة',
                  value: _pendingStatus,
                  allLabel: 'كل الحالات',
                  items: const ['pending', 'approved', 'paid'],
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _selectedYear = now.year;
                            _selectedMonth = now.month;
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
                      child: FilledButton(
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
            ),
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
      title: 'الرواتب الشهرية',
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
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _summaryHeader(),
                      const SizedBox(height: 12),
                      if (_isCalculating) ...[
                        LinearProgressIndicator(
                          minHeight: 3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'جاري حساب الرواتب وفق الفلاتر المحددة...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!_isCalculating && _reports.isEmpty)
                        const AppEmptyState(
                          title: 'لا توجد نتائج',
                          message: 'لا توجد رواتب مطابقة للفلاتر المحددة.',
                          icon: Icons.payments_outlined,
                        )
                      else
                        ..._groupedReports().entries.map(_monthSection),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _summaryHeader() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'الفترة والفلترة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showFiltersSheet,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('تعديل'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text('السنة: ${_selectedYear?.toString() ?? 'الكل'}'),
              ),
              Chip(
                label: Text(
                  'الشهر: ${_selectedMonth == null ? 'الكل' : _monthNames[_selectedMonth! - 1]}',
                ),
              ),
              Chip(label: Text('الموظف: ${_employeeFilterLabel()}')),
              Chip(label: Text('الحالة: ${_filterStatusLabel()}')),
              Chip(label: Text(_fridayMode.label)),
            ],
          ),
        ],
      ),
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
      margin: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[first.month - 1]} ${first.year}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text('${entry.value.length} موظف'),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  children: entry.value
                      .map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _mobilePayrollCard(report),
                        ),
                      )
                      .toList(),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الموظف')),
                    DataColumn(label: Text('الاستحقاق')),
                    DataColumn(label: Text('الحضور')),
                    DataColumn(label: Text('الغياب')),
                    DataColumn(label: Text('خصم الغياب')),
                    DataColumn(label: Text('الجزاءات')),
                    DataColumn(label: Text('السلف')),
                    DataColumn(label: Text('الصافي')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('الإجراءات')),
                  ],
                  rows: entry.value.map(_reportRow).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mobilePayrollCard(MonthlySalaryReport report) {
    final status = _statusForReport(report);
    final canApprove = status != 'approved' && status != 'paid';
    final approving =
        _approvingKey ==
        _reportKey(report.employee.id, report.year, report.month);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    report.employee.fullName.trim().isEmpty
                        ? 'م'
                        : report.employee.fullName.trim()[0],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(report.employee.employeeNumber),
                    ],
                  ),
                ),
                AppStatusPill(
                  color: _statusColor(status),
                  label: _statusLabel(status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _moneyLine('الاستحقاق الكلي', report.grossSalary),
            _moneyLine('خصم الغياب', report.absenceDeduction, negative: true),
            _moneyLine(
              'خصم الجزاءات',
              report.penaltiesDeduction,
              negative: true,
            ),
            _moneyLine('خصم السلف', report.advanceDeduction, negative: true),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الصافي: ${Formatters.money(report.netSalary)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showReportDetails(report),
                  child: const Text('التفاصيل'),
                ),
              ],
            ),
            if (canApprove) ...[
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: approving ? null : () => _approvePayroll(report),
                icon: approving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('اعتماد الراتب'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moneyLine(String label, num value, {bool negative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${negative && value != 0 ? '-' : ''}${Formatters.money(value)}',
          ),
        ],
      ),
    );
  }

  DataRow _reportRow(MonthlySalaryReport report) {
    final status = _statusForReport(report);
    final canApprove = status != 'approved' && status != 'paid';
    final approving =
        _approvingKey ==
        _reportKey(report.employee.id, report.year, report.month);

    return DataRow(
      cells: [
        DataCell(
          TextButton(
            onPressed: () => _showReportDetails(report),
            child: Text(report.employee.fullName),
          ),
        ),
        DataCell(Text(Formatters.money(report.grossSalary))),
        DataCell(Text(report.presentDays.toString())),
        DataCell(Text(report.absentDays.toString())),
        DataCell(Text('-${Formatters.money(report.absenceDeduction)}')),
        DataCell(Text('-${Formatters.money(report.penaltiesDeduction)}')),
        DataCell(Text('-${Formatters.money(report.advanceDeduction)}')),
        DataCell(Text(Formatters.money(report.netSalary))),
        DataCell(
          AppStatusPill(
            color: _statusColor(status),
            label: _statusLabel(status),
          ),
        ),
        DataCell(
          canApprove
              ? TextButton.icon(
                  onPressed: approving ? null : () => _approvePayroll(report),
                  icon: approving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('اعتماد'),
                )
              : TextButton(
                  onPressed: () => _showReportDetails(report),
                  child: const Text('عرض'),
                ),
        ),
      ],
    );
  }

  Future<void> _showReportDetails(MonthlySalaryReport report) {
    final status = _statusForReport(report);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.employee.fullName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${report.employee.employeeNumber} • ${_monthNames[report.month - 1]} ${report.year}',
                        ),
                      ],
                    ),
                  ),
                  AppStatusPill(
                    color: _statusColor(status),
                    label: _statusLabel(status),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _detailRow(
                    'الراتب الأساسي',
                    Formatters.money(report.baseSalary),
                  ),
                  _detailRow(
                    'المكافأة الشهرية',
                    Formatters.money(report.monthlyBonus),
                  ),
                  _detailRow(
                    'الاستحقاق الكلي',
                    Formatters.money(report.grossSalary),
                  ),
                  _detailRow('طريقة الجمعة', report.fridayMode.label),
                  _detailRow('عدد أيام الشهر', report.daysInMonth.toString()),
                  _detailRow('أيام الجمعة', report.fridaysCount.toString()),
                  _detailRow(
                    'أيام الراتب المعتمدة',
                    report.salaryDays.toString(),
                  ),
                  _detailRow('أجر اليوم', Formatters.money(report.dailyWage)),
                  _detailRow(
                    'ساعات العمل اليومية',
                    report.dailyWorkHours.toString(),
                  ),
                  _detailRow('أجر الساعة', Formatters.money(report.hourlyWage)),
                  _detailRow('أيام الحضور', report.presentDays.toString()),
                  _detailRow('أيام الغياب', report.absentDays.toString()),
                  _detailRow(
                    'راتب الحضور',
                    Formatters.money(report.attendanceSalary),
                  ),
                  _detailRow(
                    'خصم الغياب',
                    Formatters.money(report.absenceDeduction),
                  ),
                  _detailRow(
                    'خصم الجزاءات',
                    Formatters.money(report.penaltiesDeduction),
                  ),
                  _detailRow(
                    'خصم السلف',
                    Formatters.money(report.advanceDeduction),
                  ),
                  const Divider(height: 24),
                  _detailRow(
                    'صافي الراتب',
                    Formatters.money(report.netSalary),
                    strong: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: strong
                  ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _reportKey(String employeeId, int year, int month) {
    return '$employeeId-$year-${month.toString().padLeft(2, '0')}';
  }

  String _statusForReport(MonthlySalaryReport report) {
    final status =
        _payrollStatusesByMonth[_reportKey(
          report.employee.id,
          report.year,
          report.month,
        )];
    if (status == null || status.trim().isEmpty || status == 'draft') {
      return 'pending';
    }
    return status;
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'paid' => 'تم الصرف',
      'approved' => 'معتمد',
      'pending' => 'قيد المراجعة',
      _ => 'قيد المراجعة',
    };
  }

  String _filterStatusLabel() {
    if (_selectedStatus == null) return 'الكل';
    return _statusLabel(_selectedStatus);
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'paid' => AppColors.success,
      'approved' => AppColors.primary,
      _ => AppColors.warning,
    };
  }

  String _employeeFilterLabel() {
    if (_selectedEmployeeId == null) return 'الكل';
    for (final employee in _employees) {
      if (employee.id == _selectedEmployeeId) return employee.fullName;
    }
    return 'موظف محدد';
  }
}
