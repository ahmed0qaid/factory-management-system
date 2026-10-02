import re

with open('lib/screens/admin/manage_payroll_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add imports
content = "import '../../services/company_context_service.dart';\n" + content
content = "import '../../services/payroll_period_service.dart';\n" + content

# 2. Update state variables
content = re.sub(
    r"int\? _selectedYear;\s*int\? _pendingYear;\s*int\? _selectedMonth;\s*int\? _pendingMonth;",
    r"PayrollPeriodModel? _selectedPeriod;\n  PayrollPeriodModel? _pendingPeriod;\n  List<PayrollPeriodModel> _periods = [];\n  final PayrollPeriodService _periodService = PayrollPeriodService();",
    content,
    count=1
)

# 3. Update _init
init_logic = """
  Future<void> _init() async {
    try {
      final companyId = await CompanyContextService.getCurrentCompanyId();
      if (companyId == null) return;
      
      final employees = await _service.getEmployees(companyId);
      final periods = await _periodService.listPeriods(companyId);

      if (mounted) {
        setState(() {
          _employees = employees;
          _periods = periods;
          if (_periods.isNotEmpty) {
            _selectedPeriod = _periods.first;
            _pendingPeriod = _periods.first;
          }
        });
        await _calculateReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحميل: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
"""
content = re.sub(
    r"Future<void> _init\(\) async \{.*?\s+try \{.*?\}\s+\}",
    init_logic,
    content,
    flags=re.DOTALL
)

# 4. Update _calculateReports
calc_logic = """
  Future<void> _calculateReports() async {
    if (!mounted) return;
    if (_selectedPeriod == null) {
      setState(() {
        _isCalculating = false;
        _isLoading = false;
        _reports = [];
      });
      return;
    }

    final year = _selectedPeriod!.year;
    final month = _selectedPeriod!.month;

    final employees = _selectedEmployeeId == null
        ? _employees
        : _employees
              .where((employee) => employee.id == _selectedEmployeeId)
              .toList();

    setState(() {
      _isLoading = true;
      _isCalculating = true;
      _reports = [];
    });

    try {
      final reports = <MonthlySalaryReport>[];
      const concurrency = 8;

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

      reports.sort((a, b) {
        final byDate = b.monthKey.compareTo(a.monthKey);
        if (byDate != 0) return byDate;
        return a.employee.fullName.compareTo(b.employee.fullName);
      });

      final historicalRows = await _service.getPayrollRows();
      _payrollStatusesByMonth.clear();
      for (final row in historicalRows) {
         if (row.data['payroll_period_id'] == _selectedPeriod!.id) {
             final k = _reportKey(row.data['employee_id'], year, month);
             _payrollStatusesByMonth[k] = row.data['status'] as String? ?? 'approved';
         }
      }

      if (mounted) {
        setState(() {
          _reports = reports;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل بيانات الرواتب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; _isCalculating = false; });
    }
  }
"""

content = re.sub(
    r"Future<void> _calculateReports\(\) async \{.*?finally \{\s*if \(mounted\) setState\(\(\) => _isLoading = false\);\s*\}\s*\}",
    calc_logic,
    content,
    flags=re.DOTALL
)

# 5. Fix UI building filters (replace year and month dropdowns with period dropdown)
filter_ui_logic = """
                        Expanded(
                          child: DropdownButtonFormField<PayrollPeriodModel?>(
                            decoration: const InputDecoration(
                              labelText: 'الفترة المالية',
                              border: OutlineInputBorder(),
                            ),
                            value: _pendingPeriod,
                            items: _periods.map((p) {
                              final label = '${_monthNames[p.month - 1]} ${p.year} (${p.periodKey}) - ${p.status}';
                              return DropdownMenuItem(
                                value: p,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _pendingPeriod = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _showCreatePeriodDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('فترة جديدة'),
                        ),
"""

# I will find the row that has year and month dropdowns
# The original code looks like: Expanded(child: DropdownButtonFormField<int?>(... 'السنة' ... Expanded(child: DropdownButtonFormField<int?>(... 'الشهر'
# I will replace it using a regex that captures everything inside the Row children before the "EmployeePickerField".
# Let's replace the whole `Wrap` or `Row` inside the Filter card.

filter_full = r"""
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
""" + filter_ui_logic + r"""
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: EmployeePickerField(
"""

content = re.sub(
    r"children: \[\s*Row\(\s*crossAxisAlignment: CrossAxisAlignment\.end,\s*children: \[\s*Expanded\(\s*child: DropdownButtonFormField<int\?>\(\s*decoration: const InputDecoration\(\s*labelText: 'السنة'.*?child: EmployeePickerField\(",
    filter_full,
    content,
    flags=re.DOTALL
)

# Apply filter sets `_selectedPeriod = _pendingPeriod`
content = re.sub(
    r"_selectedYear = _pendingYear;\s*_selectedMonth = _pendingMonth;",
    r"_selectedPeriod = _pendingPeriod;",
    content
)

# 6. Block approval if closed
approve_block = """
  Future<void> _approvePayroll(MonthlySalaryReport report) async {
    if (_selectedPeriod?.status == 'closed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إصدار راتب في فترة مغلقة.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }
    final status = _statusForReport(report);
"""
content = re.sub(
    r"Future<void> _approvePayroll\(MonthlySalaryReport report\) async \{\s*final status = _statusForReport\(report\);",
    approve_block,
    content
)

# 7. Provide `_showCreatePeriodDialog` and `_closePeriod` functions
extra_funcs = """
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
        content: const Text('هل أنت متأكد من إغلاق هذه الفترة؟'),
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
"""

content = re.sub(
    r"Widget _moneyLine\(String label, num value, \{bool negative = false\}\) \{",
    extra_funcs + r"\n  Widget _moneyLine(String label, num value, {bool negative = false}) {",
    content
)

# 8. Add _closePeriod button to UI near filter (next to apply button)
# We can inject it in the actions of the filter card
close_btn = """
                        if (_selectedPeriod != null && _selectedPeriod!.status == 'open')
                           ElevatedButton.icon(
                             onPressed: _closePeriod,
                             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                             icon: const Icon(Icons.lock),
                             label: const Text('إغلاق الفترة'),
                           ),
                        const SizedBox(width: 8),
"""
content = re.sub(
    r"(ElevatedButton\.icon\(\s*onPressed: _calculateReports,\s*icon: const Icon\(Icons\.filter_list\),\s*label: const Text\('تطبيق'\),\s*\),)",
    close_btn + r"\1",
    content
)

with open('lib/screens/admin/manage_payroll_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
