import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/employee_report_service.dart';
import '../../widgets/common/app_scaffold.dart';

enum ReportKind {
  attendance,
  payroll,
  advances,
  penalties,
  leaves,
  overtime,
  documents,
}

class ReportListScreen extends StatefulWidget {
  final ProfileModel currentProfile;
  final ReportKind kind;

  const ReportListScreen({
    super.key,
    required this.currentProfile,
    required this.kind,
  });

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  final _service = EmployeeReportService();
  late Future<List<ProfileModel>> _employeesFuture;
  Future<List<models.Row>>? _rowsFuture;
  String? _selectedEmployeeId;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _service.getEmployees();
    _loadRows();
  }

  _ReportMeta get _meta => switch (widget.kind) {
    ReportKind.attendance => const _ReportMeta(
      title: 'تقارير الحضور والانصراف',
      icon: Icons.calendar_month_outlined,
    ),
    ReportKind.payroll => const _ReportMeta(
      title: 'تقارير الرواتب',
      icon: Icons.payments_outlined,
    ),
    ReportKind.advances => const _ReportMeta(
      title: 'تقارير السلف',
      icon: Icons.account_balance_wallet_outlined,
    ),
    ReportKind.penalties => const _ReportMeta(
      title: 'تقارير الجزاءات',
      icon: Icons.gavel_outlined,
    ),
    ReportKind.leaves => const _ReportMeta(
      title: 'تقارير الإجازات',
      icon: Icons.event_available_outlined,
    ),
    ReportKind.overtime => const _ReportMeta(
      title: 'تقارير العمل الإضافي',
      icon: Icons.timer_outlined,
    ),
    ReportKind.documents => const _ReportMeta(
      title: 'تقارير مستندات الموظفين',
      icon: Icons.folder_copy_outlined,
    ),
  };

  void _loadRows() {
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ البداية يجب أن يسبق تاريخ النهاية.')),
      );
      return;
    }

    setState(() {
      _rowsFuture = switch (widget.kind) {
        ReportKind.attendance => _service.getAttendanceReport(
          employeeId: _selectedEmployeeId,
          from: _from,
          to: _to,
        ),
        ReportKind.payroll => _service.getPayrollReport(
          employeeId: _selectedEmployeeId,
          from: _from,
          to: _to,
        ),
        ReportKind.advances => _service.getAdvancesReport(
          employeeId: _selectedEmployeeId,
          from: _from,
          to: _to,
        ),
        ReportKind.penalties => _service.getPenaltiesReport(
          employeeId: _selectedEmployeeId,
          from: _from,
          to: _to,
        ),
        ReportKind.leaves => _service.getLeavesReport(
          employeeId: _selectedEmployeeId,
          from: _from,
          to: _to,
        ),
        ReportKind.overtime => _service.getOvertimeReport(
          employeeId: _selectedEmployeeId,
          from: _from,
          to: _to,
        ),
        ReportKind.documents => _service.getDocumentsReport(
          employeeId: _selectedEmployeeId,
        ),
      };
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedEmployeeId = null;
      _from = null;
      _to = null;
    });
    _loadRows();
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

  String _dateValue(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? value.toString() : _date(parsed);
  }

  String _money(num value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

  num _num(Map<String, dynamic> data, String key) => data[key] as num? ?? 0;

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final compact = MediaQuery.sizeOf(context).width < 600;

    return AppScaffold(
      title: meta.title,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'خيارات التصدير',
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              enabled: false,
              value: 'pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('تصدير PDF'),
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              enabled: false,
              value: 'excel',
              child: ListTile(
                leading: Icon(Icons.table_chart_outlined),
                title: Text('تصدير Excel'),
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              enabled: false,
              value: 'print',
              child: ListTile(
                leading: Icon(Icons.print_outlined),
                title: Text('طباعة'),
                dense: true,
              ),
            ),
          ],
        ),
      ],
      body: FutureBuilder<List<ProfileModel>>(
        future: _employeesFuture,
        builder: (context, employeesSnapshot) {
          if (!employeesSnapshot.hasData && !employeesSnapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (employeesSnapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'تعذر تحميل الموظفين',
              message: '${employeesSnapshot.error}',
            );
          }
          final employees = employeesSnapshot.data ?? const <ProfileModel>[];
          final employeeNames = {
            for (final employee in employees) employee.id: employee.fullName,
          };
          return ListView(
            padding: EdgeInsets.all(compact ? 10 : 16),
            children: [
              _filters(employees),
              const SizedBox(height: 12),
              FutureBuilder<List<models.Row>>(
                future: _rowsFuture,
                builder: (context, rowsSnapshot) {
                  if (!rowsSnapshot.hasData && !rowsSnapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (rowsSnapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.error_outline,
                      title: 'تعذر تحميل التقرير',
                      message: '${rowsSnapshot.error}',
                    );
                  }
                  final rows = rowsSnapshot.data ?? const <models.Row>[];
                  if (rows.isEmpty) {
                    return _StateMessage(
                      icon: meta.icon,
                      title: 'لا توجد بيانات',
                      message: 'لا توجد سجلات مطابقة للفلاتر الحالية.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _summary(rows),
                      const SizedBox(height: 12),
                      ...rows.map((row) => _rowTile(row, employeeNames)),
                    ],
                  );
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
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;

            final employeeField = DropdownButtonFormField<String?>(
              initialValue: _selectedEmployeeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الموظف',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('كل الموظفين'),
                ),
                ...employees.map(
                  (employee) => DropdownMenuItem<String?>(
                    value: employee.id,
                    child: Text(
                      '${employee.fullName} - ${employee.employeeNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedEmployeeId = value),
            );

            final fromButton = OutlinedButton.icon(
              onPressed: () => _pickDate(true),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                'من: ${_date(_from)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
            final toButton = OutlinedButton.icon(
              onPressed: () => _pickDate(false),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                'إلى: ${_date(_to)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
            final showButton = FilledButton.icon(
              onPressed: _loadRows,
              icon: const Icon(Icons.search),
              label: const Text('عرض التقرير'),
            );
            final clearButton = TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('مسح الفلاتر'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  employeeField,
                  if (widget.kind != ReportKind.documents) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: fromButton),
                        const SizedBox(width: 8),
                        Expanded(child: toButton),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  showButton,
                  const SizedBox(height: 4),
                  clearButton,
                ],
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 320, child: employeeField),
                if (widget.kind != ReportKind.documents) ...[
                  fromButton,
                  toButton,
                ],
                showButton,
                clearButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary(List<models.Row> rows) {
    final cards = switch (widget.kind) {
      ReportKind.attendance => [
        _summaryCard('السجلات', rows.length.toString(), Icons.list_alt_outlined),
        _summaryCard(
          'الحضور',
          rows
              .where(
                (row) =>
                    row.data['status'] == 'present' ||
                    row.data['check_in'] != null,
              )
              .length
              .toString(),
          Icons.check_circle_outline,
        ),
        _summaryCard(
          'الغياب',
          rows.where((row) => row.data['status'] == 'absent').length.toString(),
          Icons.cancel_outlined,
        ),
        _summaryCard(
          'التأخير',
          rows
              .where((row) => _num(row.data, 'late_minutes') > 0)
              .length
              .toString(),
          Icons.schedule_outlined,
        ),
      ],
      ReportKind.payroll => [
        _summaryCard('السجلات', rows.length.toString(), Icons.list_alt_outlined),
        _summaryCard(
          'صافي الرواتب',
          _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'net_salary'))),
          Icons.payments_outlined,
        ),
        _summaryCard(
          'الإضافات',
          _money(
            rows.fold<num>(
              0,
              (sum, row) =>
                  sum +
                  _num(row.data, 'allowances') +
                  _num(row.data, 'bonuses') +
                  _num(row.data, 'overtime_amount'),
            ),
          ),
          Icons.add_circle_outline,
        ),
        _summaryCard(
          'الخصومات',
          _money(
            rows.fold<num>(
              0,
              (sum, row) =>
                  sum +
                  _num(row.data, 'absence_deductions') +
                  _num(row.data, 'late_deductions') +
                  _num(row.data, 'penalties_amount') +
                  _num(row.data, 'advance_installments') +
                  _num(row.data, 'other_deductions'),
            ),
          ),
          Icons.remove_circle_outline,
        ),
      ],
      ReportKind.advances => [
        _summaryCard('السجلات', rows.length.toString(), Icons.list_alt_outlined),
        _summaryCard(
          'إجمالي السلف',
          _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'principal_amount'))),
          Icons.account_balance_wallet_outlined,
        ),
        _summaryCard(
          'المتبقي',
          _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'remaining_amount'))),
          Icons.pending_actions_outlined,
        ),
      ],
      ReportKind.penalties => [
        _summaryCard('السجلات', rows.length.toString(), Icons.list_alt_outlined),
        _summaryCard(
          'إجمالي الجزاءات',
          _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'amount'))),
          Icons.gavel_outlined,
        ),
        _summaryCard(
          'دقائق الخصم',
          rows
              .fold<num>(0, (sum, row) => sum + _num(row.data, 'minutes_deducted'))
              .toString(),
          Icons.timer_off_outlined,
        ),
      ],
      ReportKind.leaves => [
        _summaryCard('الطلبات', rows.length.toString(), Icons.event_available_outlined),
        _summaryCard(
          'المعتمدة',
          rows.where((row) => row.data['status'] == 'approved').length.toString(),
          Icons.check_circle_outline,
        ),
        _summaryCard(
          'المعلقة',
          rows.where((row) => row.data['status'] == 'pending').length.toString(),
          Icons.pending_actions_outlined,
        ),
      ],
      ReportKind.overtime => [
        _summaryCard('السجلات', rows.length.toString(), Icons.list_alt_outlined),
        _summaryCard(
          'الساعات',
          (rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'overtime_minutes')) / 60)
              .toStringAsFixed(1),
          Icons.timer_outlined,
        ),
        _summaryCard(
          'القيمة',
          _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'overtime_amount'))),
          Icons.payments_outlined,
        ),
      ],
      ReportKind.documents => [
        _summaryCard('المستندات', rows.length.toString(), Icons.folder_copy_outlined),
        _summaryCard(
          'لها ملف',
          rows.where((row) => row.data['file_id'] != null).length.toString(),
          Icons.attach_file_outlined,
        ),
      ],
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map(
                (card) => SizedBox(
                  width: compact ? constraints.maxWidth : 190,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Card(
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
    );
  }

  Widget _rowTile(models.Row row, Map<String, String> employeeNames) {
    final data = row.data;
    final employee = employeeNames[data['employee_id']] ?? data['employee_id'] ?? '-';
    return Card(
      child: ListTile(
        leading: Icon(_meta.icon),
        title: Text(_title(data), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'الموظف: $employee\n${_subtitle(data)}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 74),
          child: Text(
            _trailing(data),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _title(Map<String, dynamic> data) => switch (widget.kind) {
    ReportKind.attendance => 'تاريخ الدوام: ${_dateValue(data['work_date'])}',
    ReportKind.payroll =>
      '${data['period_name'] ?? 'مسير راتب'} - صافي ${_money(_num(data, 'net_salary'))}',
    ReportKind.advances => 'سلفة ${_money(_num(data, 'principal_amount'))}',
    ReportKind.penalties => '${data['category'] ?? 'جزاء'}',
    ReportKind.leaves => '${data['leave_type'] ?? 'إجازة'}',
    ReportKind.overtime =>
      'عمل إضافي ${(_num(data, 'overtime_minutes') / 60).toStringAsFixed(1)} ساعة',
    ReportKind.documents =>
      '${data['title'] ?? data['document_type'] ?? data['file_name'] ?? 'مستند'}',
  };

  String _subtitle(Map<String, dynamic> data) => switch (widget.kind) {
    ReportKind.attendance =>
      'دخول: ${_dateValue(data['check_in'])} | خروج: ${_dateValue(data['check_out'])} | ساعات: ${(_num(data, 'worked_minutes') / 60).toStringAsFixed(1)}',
    ReportKind.payroll =>
      'أساسي: ${_money(_num(data, 'base_salary'))} | إضافات: ${_money(_num(data, 'allowances') + _num(data, 'bonuses') + _num(data, 'overtime_amount'))} | خصومات: ${_money(_num(data, 'absence_deductions') + _num(data, 'late_deductions') + _num(data, 'penalties_amount') + _num(data, 'advance_installments') + _num(data, 'other_deductions'))}',
    ReportKind.advances =>
      'التاريخ: ${_dateValue(data['created_at'])} | القسط: ${_money(_num(data, 'installment_amount'))} | المتبقي: ${_money(_num(data, 'remaining_amount'))}',
    ReportKind.penalties =>
      'التاريخ: ${_dateValue(data['penalty_date'])} | السبب: ${data['reason'] ?? '-'} | القيمة: ${_money(_num(data, 'amount'))}',
    ReportKind.leaves =>
      'من ${_dateValue(data['start_date'])} إلى ${_dateValue(data['end_date'])} | السبب: ${data['reason'] ?? '-'}',
    ReportKind.overtime =>
      'التاريخ: ${_dateValue(data['work_date'])} | القيمة: ${_money(_num(data, 'overtime_amount'))} | الدفع: ${data['payment_status'] ?? '-'}',
    ReportKind.documents =>
      'النوع: ${data['document_type'] ?? '-'} | الملف: ${data['file_name'] ?? data['file_id'] ?? '-'}',
  };

  String _trailing(Map<String, dynamic> data) => switch (widget.kind) {
    ReportKind.attendance => '${data['status'] ?? '-'}',
    ReportKind.payroll => '${data['status'] ?? '-'}',
    ReportKind.advances => '${data['status'] ?? '-'}',
    ReportKind.penalties => '${data['status'] ?? '-'}',
    ReportKind.leaves => '${data['status'] ?? '-'}',
    ReportKind.overtime => '${data['approval_status'] ?? '-'}',
    ReportKind.documents => data['file_id'] == null ? '-' : 'ملف',
  };
}

class _ReportMeta {
  final String title;
  final IconData icon;

  const _ReportMeta({required this.title, required this.icon});
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
