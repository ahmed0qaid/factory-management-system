import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../models/attendance_model.dart';
import '../../models/employee_full_report_model.dart';
import '../../models/leave_model.dart';
import '../../models/overtime_record_model.dart';
import '../../models/payroll_model.dart';
import '../../models/penalty_model.dart';
import '../../models/profile_model.dart';
import '../../services/employee_report_service.dart';
import '../../widgets/common/app_scaffold.dart';

class EmployeeFullReportScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const EmployeeFullReportScreen({super.key, required this.currentProfile});

  @override
  State<EmployeeFullReportScreen> createState() =>
      _EmployeeFullReportScreenState();
}

class _EmployeeFullReportScreenState extends State<EmployeeFullReportScreen> {
  final _service = EmployeeReportService();
  late Future<List<ProfileModel>> _employeesFuture;
  Future<EmployeeFullReport>? _reportFuture;
  String? _selectedEmployeeId;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
  }

  Future<List<ProfileModel>> _loadEmployees() async {
    final employees = await _service.getEmployees();
    if (employees.isNotEmpty && _selectedEmployeeId == null) {
      _selectedEmployeeId = employees.first.id;
    }
    return employees;
  }

  void _loadReport() {
    final employeeId = _selectedEmployeeId;
    if (employeeId == null) return;
    setState(() {
      _reportFuture = _service.getEmployeeFullReport(
        employeeId: employeeId,
        from: _from,
        to: _to,
      );
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String _date(DateTime? value) {
    if (value == null) return '-';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _money(num value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'التقرير الشامل للموظف',
      actions: [
        IconButton(
          tooltip: 'تصدير PDF',
          onPressed: null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
        IconButton(
          tooltip: 'تصدير Excel',
          onPressed: null,
          icon: const Icon(Icons.table_chart_outlined),
        ),
        IconButton(
          tooltip: 'طباعة',
          onPressed: null,
          icon: const Icon(Icons.print_outlined),
        ),
      ],
      body: FutureBuilder<List<ProfileModel>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'تعذر تحميل الموظفين',
              message: '${snapshot.error}',
            );
          }
          final employees = snapshot.data ?? const <ProfileModel>[];
          if (employees.isEmpty) {
            return const _StateMessage(
              icon: Icons.people_outline,
              title: 'لا يوجد موظفون',
              message: 'لا توجد بيانات موظفين متاحة للتقرير.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _filters(employees),
              const SizedBox(height: 12),
              if (_reportFuture == null)
                const _StateMessage(
                  icon: Icons.analytics_outlined,
                  title: 'اختر موظفًا',
                  message: 'حدد الموظف والفترة ثم اضغط عرض التقرير.',
                )
              else
                FutureBuilder<EmployeeFullReport>(
                  future: _reportFuture,
                  builder: (context, reportSnapshot) {
                    if (reportSnapshot.connectionState !=
                        ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (reportSnapshot.hasError) {
                      return _StateMessage(
                        icon: Icons.error_outline,
                        title: 'تعذر تحميل التقرير',
                        message: '${reportSnapshot.error}',
                      );
                    }
                    return _report(reportSnapshot.data!);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters(List<ProfileModel> employees) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedEmployeeId,
                decoration: const InputDecoration(
                  labelText: 'اختيار الموظف',
                  border: OutlineInputBorder(),
                ),
                items: employees
                    .map(
                      (employee) => DropdownMenuItem(
                        value: employee.id,
                        child: Text(
                          '${employee.fullName} - ${employee.employeeNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedEmployeeId = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(true),
              icon: const Icon(Icons.date_range_outlined),
              label: Text('من: ${_date(_from)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(false),
              icon: const Icon(Icons.event_outlined),
              label: Text('إلى: ${_date(_to)}'),
            ),
            FilledButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.search),
              label: const Text('عرض التقرير'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _report(EmployeeFullReport report) {
    return Column(
      children: [
        _employeeHeader(report.employee),
        const SizedBox(height: 12),
        _summary(report),
        const SizedBox(height: 12),
        _section(
          title: 'الحضور والانصراف',
          icon: Icons.calendar_month_outlined,
          count: report.attendance.length,
          child: _attendance(report.attendance),
        ),
        _section(
          title: 'الرواتب',
          icon: Icons.payments_outlined,
          count: report.payroll.length,
          child: _payroll(report.payroll),
        ),
        _section(
          title: 'السلف',
          icon: Icons.account_balance_wallet_outlined,
          count: report.advances.length,
          child: _advances(report.advances),
        ),
        _section(
          title: 'الجزاءات',
          icon: Icons.gavel_outlined,
          count: report.penalties.length,
          child: _penalties(report.penalties),
        ),
        _section(
          title: 'الإجازات',
          icon: Icons.event_available_outlined,
          count: report.leaves.length,
          child: _leaves(report.leaves),
        ),
        _section(
          title: 'العمل الإضافي',
          icon: Icons.timer_outlined,
          count: report.overtime.length,
          child: _overtime(report.overtime),
        ),
        _section(
          title: 'مستندات الموظف',
          icon: Icons.folder_copy_outlined,
          count: report.documents.length,
          child: _documents(report),
        ),
      ],
    );
  }

  Widget _employeeHeader(ProfileModel employee) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              child: employee.photoPath == null
                  ? Text(
                      employee.fullName.isNotEmpty ? employee.fullName[0] : 'م',
                    )
                  : const Icon(Icons.person),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _field('الاسم', employee.fullName),
                  _field('الرقم الوظيفي', employee.employeeNumber),
                  _field('الدور', employee.roleLabel),
                  _field('الهاتف', employee.phone ?? '-'),
                  _field('القسم', employee.departmentName ?? '-'),
                  _field('المسمى الوظيفي', employee.jobTitleName ?? '-'),
                  _field('تاريخ التعيين', _date(employee.hireDate)),
                  _field('الحالة', employee.active ? 'نشط' : 'غير نشط'),
                  _field('الراتب الأساسي', _money(employee.baseSalary)),
                  _field('المكافأة الشهرية', _money(employee.monthlyBonus)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(EmployeeFullReport report) {
    final cards = [
      _summaryCard(
        'أيام الحضور',
        report.presentDays.toString(),
        Icons.check_circle_outline,
      ),
      _summaryCard(
        'أيام الغياب',
        report.absentDays.toString(),
        Icons.cancel_outlined,
      ),
      _summaryCard(
        'مرات التأخير',
        report.lateCount.toString(),
        Icons.schedule_outlined,
      ),
      _summaryCard(
        'إجمالي الرواتب',
        _money(report.totalPayroll),
        Icons.payments_outlined,
      ),
      _summaryCard(
        'إجمالي السلف',
        _money(report.totalAdvances),
        Icons.account_balance_wallet_outlined,
      ),
      _summaryCard(
        'السلف المتبقية',
        _money(report.remainingAdvances),
        Icons.pending_actions_outlined,
      ),
      _summaryCard(
        'إجمالي الجزاءات',
        _money(report.totalPenalties),
        Icons.gavel_outlined,
      ),
      _summaryCard(
        'إجمالي الإضافي',
        _money(report.totalOvertime),
        Icons.timer_outlined,
      ),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: cards);
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(value, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required int count,
    required Widget child,
  }) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(count == 0 ? 'لا توجد بيانات' : 'عدد السجلات: $count'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _attendance(List<AttendanceRecordModel> rows) {
    if (rows.isEmpty) return const Text('لا توجد سجلات حضور لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(_date(row.workDate)),
              subtitle: Text(
                'دخول: ${_dateTime(row.checkIn)} | خروج: ${_dateTime(row.checkOut)}',
              ),
              trailing: Text(
                '${(row.workedMinutes / 60).toStringAsFixed(1)} س',
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _payroll(List<PayrollRecordModel> rows) {
    if (rows.isEmpty) return const Text('لا توجد سجلات رواتب لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text('الصافي: ${_money(row.netSalary)}'),
              subtitle: Text(
                'أساسي: ${_money(row.baseSalary)} | إضافات: ${_money(row.allowances + row.bonuses + row.overtimeAmount)} | خصومات: ${_money(row.absenceDeductions + row.lateDeductions + row.penaltiesAmount + row.advanceInstallments + row.otherDeductions)}',
              ),
              trailing: Text(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _advances(List<AdvanceModel> rows) {
    if (rows.isEmpty) return const Text('لا توجد سلف لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('السلفة: ${_money(row.principalAmount)}'),
              subtitle: Text(
                'التاريخ: ${_date(row.requestDate)} | المتبقي: ${_money(row.remainingAmount)}',
              ),
              trailing: Text(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _penalties(List<PenaltyModel> rows) {
    if (rows.isEmpty) return const Text('لا توجد جزاءات لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(row.category),
              subtitle: Text('${_date(row.penaltyDate)} | ${row.reason}'),
              trailing: Text(_money(row.amount)),
            ),
          )
          .toList(),
    );
  }

  Widget _leaves(List<LeaveModel> rows) {
    if (rows.isEmpty) return const Text('لا توجد إجازات لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: Text(row.leaveType),
              subtitle: Text(
                '${_date(row.startDate)} إلى ${_date(row.endDate)}',
              ),
              trailing: Text(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _overtime(List<OvertimeRecordModel> rows) {
    if (rows.isEmpty) return const Text('لا توجد سجلات عمل إضافي لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(
                '${(row.overtimeMinutes / 60).toStringAsFixed(1)} ساعة',
              ),
              subtitle: Text(_date(row.workDate)),
              trailing: Text(
                row.overtimeAmount == null
                    ? row.approvalStatus
                    : _money(row.overtimeAmount!),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _documents(EmployeeFullReport report) {
    if (report.documents.isEmpty) {
      return const Text('لا توجد مستندات لهذا الموظف.');
    }
    return Column(
      children: report.documents
          .map(
            (row) => ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(
                '${row.data['title'] ?? row.data['document_type'] ?? row.$id}',
              ),
              subtitle: Text(
                '${row.data['file_name'] ?? row.data['notes'] ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _field(String title, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '-';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_date(value)} $hour:$minute';
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
