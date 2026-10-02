import re
import sys

with open('lib/services/admin_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add imports
content = "import 'payroll_period_service.dart';\n" + content

# 2. Fix addPayroll signature
content = re.sub(
    r"Future<void> addPayroll\(\{\s*required String companyId,\s*required String employeeId,",
    "Future<void> addPayroll({\n    required String companyId,\n    required int year,\n    required int month,\n    required String employeeId,",
    content,
    count=1
)

# 3. Add Payroll Period logic
logic = """
    final payrollPeriod = await PayrollPeriodService().getOrCreatePeriod(scopedCompanyId, year, month);
    if (payrollPeriod.status == 'closed') throw Exception('لا يمكن إصدار راتب في فترة مغلقة.');
    
    final existingPayroll = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollTable,
      queries: [
        Query.equal('company_id', scopedCompanyId),
        Query.equal('employee_id', employeeId),
        Query.equal('payroll_period_id', payrollPeriod.id),
      ],
    );
    if (existingPayroll.rows.isNotEmpty) return;

    if (netSalary < 0) throw Exception('لا يمكن اعتماد الراتب لأن الصافي بالسالب. الرجاء مراجعة الخصومات أو الأقساط.');
    
    final payrollId = ID.unique();
"""
content = re.sub(
    r"final payrollId = ID\.unique\(\);",
    logic,
    content,
    count=1
)

# 4. Add payroll_period_id to createRow
content = re.sub(
    r"('employee_id': employeeId,)\s*('base_salary': baseSalary,)",
    r"\1\n        'payroll_period_id': payrollPeriod.id,\n        'period_key': payrollPeriod.periodKey,\n        \2",
    content,
    count=1
)

# 5. Add installment deduction before notification IN ADD_PAYROLL
deduction_logic = """
    final dueMonth = '${year}-${month.toString().padLeft(2, '0')}';
    final installmentsData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advanceInstallmentsTable,
      queries: [
        Query.equal('company_id', scopedCompanyId),
        Query.equal('employee_id', employeeId),
        Query.equal('due_month', dueMonth),
        Query.equal('status', 'pending'),
      ],
    );
    for (final inst in installmentsData.rows) {
      final amount = inst.data['amount'] as num? ?? 0;
      final advId = inst.data['advance_id']?.toString() ?? '';
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advanceInstallmentsTable,
        rowId: inst.$id,
        data: {
          'status': 'deducted',
          'payroll_record_id': payrollId,
          'deducted_at': DateTime.now().toIso8601String(),
        },
      );
      final advRow = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advId,
      );
      num remaining = (advRow.data['remaining_amount'] as num? ?? 0) - amount;
      if (remaining < 0) remaining = 0;
      final advUpdate = <String, dynamic>{'remaining_amount': remaining};
      if (remaining <= 0) {
        advUpdate['repayment_status'] = 'fully_paid';
      }
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advId,
        data: advUpdate,
      );
    }
"""

# Find the end of the first AppwriteService.tablesDB.createRow( in addPayroll
# and inject the deduction_logic after it
pattern = r"""
        Permission\.update\(
          Role\.team\(scopedCompanyId, AppRoles\.financialManager\),
        \),
      \],
    \);
"""

replacement = r"""
        Permission.update(
          Role.team(scopedCompanyId, AppRoles.financialManager),
        ),
      ],
    );
""" + deduction_logic

content = re.sub(pattern, replacement, content, count=1)

# Add periodKey and payrollPeriodId to Notification
content = re.sub(
    r"('type': 'payroll',)",
    r"'payroll_period_id': payrollPeriod.id,\n        'period_key': payrollPeriod.periodKey,\n        \1",
    content,
    count=1
)

with open('lib/services/admin_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("done")
