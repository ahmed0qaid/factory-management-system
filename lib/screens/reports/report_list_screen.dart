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
  _PeriodPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _service.getEmployees();
    _loadRows();
  }

  _ReportMeta get _meta => switch (widget.kind) {
        ReportKind.attendance => const _ReportMeta(
            title: 'الحضور والانصراف',
            description: 'الحضور والغياب والتأخير وساعات العمل',
            icon: Icons.calendar_month_outlined,
          ),
        ReportKind.payroll => const _ReportMeta(
            title: 'الرواتب',
            description: 'صافي الرواتب والإضافات والخصومات',
            icon: Icons.payments_outlined,
          ),
        ReportKind.advances => const _ReportMeta(
            title: 'السلف',
            description: 'السلف والأقساط والمبالغ المتبقية',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ReportKind.penalties => const _ReportMeta(
            title: 'الجزاءات',
            description: 'الجزاءات والقيم ودقائق الخصم',
            icon: Icons.gavel_outlined,
          ),
        ReportKind.leaves => const _ReportMeta(
            title: 'الإجازات',
            description: 'طلبات الإجازة وحالات الاعتماد',
            icon: Icons.event_available_outlined,
          ),
        ReportKind.overtime => const _ReportMeta(
            title: 'العمل الإضافي',
            description: 'الساعات الإضافية وقيمتها وحالة اعتمادها',
            icon: Icons.timer_outlined,
          ),
        ReportKind.documents => const _ReportMeta(
            title: 'مستندات الموظفين',
            description: 'الملفات والمستندات المرتبطة بالموظفين',
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
      _selectedPreset = null;
    });
    _loadRows();
  }

  void _applyPreset(_PeriodPreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from;
    DateTime to;

    switch (preset) {
      case _PeriodPreset.today:
        from = today;
        to = today;
      case _PeriodPreset.thisWeek:
        from = today.subtract(Duration(days: today.weekday - 1));
        to = today;
      case _PeriodPreset.thisMonth:
        from = DateTime(today.year, today.month, 1);
        to = today;
      case _PeriodPreset.lastMonth:
        final previous = DateTime(today.year, today.month - 1, 1);
        from = previous;
        to = DateTime(today.year, today.month, 0);
    }

    setState(() {
      _selectedPreset = preset;
      _from = from;
      _to = to;
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
      _selectedPreset = null;
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String _date(DateTime? value) {
    if (value == null) return '';
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
    final compact = MediaQuery.sizeOf(context).width < 650;

    return AppScaffold(
      title: 'تقرير ${meta.title}',
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: EdgeInsets.all(compact ? 10 : 18),
                children: [
                  _ReportHeader(meta: meta),
                  const SizedBox(height: 12),
                  _filters(employees),
                  const SizedBox(height: 14),
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
                          message: _selectedEmployeeId == null && _from == null && _to == null
                              ? 'لا توجد سجلات متاحة حاليًا لهذا التقرير.'
                              : 'لا توجد سجلات مطابقة للفلاتر المحددة. جرّب تغيير الموظف أو الفترة.',
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _summary(rows),
                          const SizedBox(height: 14),
                          Text(
                            'تفاصيل السجلات (${rows.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ...rows.map((row) => _rowTile(row, employeeNames)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
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
            final compact = constraints.maxWidth < 600;

            final employeeField = DropdownButtonFormField<String?>(
              initialValue: _selectedEmployeeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الموظف',
                hintText: 'كل الموظفين',
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

            final dateControls = widget.kind == ReportKind.documents
                ? <Widget>[]
                : <Widget>[
                    _DateFilterButton(
                      label: 'من تاريخ',
                      value: _from == null ? 'غير محدد' : _date(_from),
                      icon: Icons.date_range_outlined,
                      onPressed: () => _pickDate(true),
                    ),
                    _DateFilterButton(
                      label: 'إلى تاريخ',
                      value: _to == null ? 'غير محدد' : _date(_to),
                      icon: Icons.event_outlined,
                      onPressed: () => _pickDate(false),
                    ),
                  ];

            final actions = Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loadRows,
                    icon: const Icon(Icons.search),
                    label: const Text('عرض التقرير'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'مسح الفلاتر',
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تصفية التقرير',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                if (compact) ...[
                  employeeField,
                  if (dateControls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...dateControls.expand((widget) => [widget, const SizedBox(height: 8)]),
                    _periodPresets(),
                  ],
                  const SizedBox(height: 10),
                  actions,
                ] else ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(width: 320, child: employeeField),
                      ...dateControls.map((widget) => SizedBox(width: 180, child: widget)),
                    ],
                  ),
                  if (dateControls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _periodPresets(),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(width: 320, child: actions),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _periodPresets() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _presetChip(_PeriodPreset.today, 'اليوم'),
        _presetChip(_PeriodPreset.thisWeek, 'هذا الأسبوع'),
        _presetChip(_PeriodPreset.thisMonth, 'هذا الشهر'),
        _presetChip(_PeriodPreset.lastMonth, 'الشهر السابق'),
      ],
    );
  }

  Widget _presetChip(_PeriodPreset preset, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedPreset == preset,
      onSelected: (_) => _applyPreset(preset),
    );
  }

  Widget _summary(List<models.Row> rows) {
    final cards = switch (widget.kind) {
      ReportKind.attendance => [
          _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
          _SummaryData(
            'الحضور',
            rows.where((row) => row.data['status'] == 'present' || row.data['check_in'] != null).length.toString(),
            Icons.check_circle_outline,
          ),
          _SummaryData('الغياب', rows.where((row) => row.data['status'] == 'absent').length.toString(), Icons.cancel_outlined),
          _SummaryData('التأخير', rows.where((row) => _num(row.data, 'late_minutes') > 0).length.toString(), Icons.schedule_outlined),
        ],
      ReportKind.payroll => [
          _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
          _SummaryData('صافي الرواتب', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'net_salary'))), Icons.payments_outlined),
          _SummaryData('الإضافات', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'allowances') + _num(row.data, 'bonuses') + _num(row.data, 'overtime_amount'))), Icons.add_circle_outline),
          _SummaryData('الخصومات', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'absence_deductions') + _num(row.data, 'late_deductions') + _num(row.data, 'penalties_amount') + _num(row.data, 'advance_installments') + _num(row.data, 'other_deductions'))), Icons.remove_circle_outline),
        ],
      ReportKind.advances => [
          _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
          _SummaryData('إجمالي السلف', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'principal_amount'))), Icons.account_balance_wallet_outlined),
          _SummaryData('المتبقي', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'remaining_amount'))), Icons.pending_actions_outlined),
        ],
      ReportKind.penalties => [
          _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
          _SummaryData('إجمالي الجزاءات', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'amount'))), Icons.gavel_outlined),
          _SummaryData('دقائق الخصم', rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'minutes_deducted')).toString(), Icons.timer_off_outlined),
        ],
      ReportKind.leaves => [
          _SummaryData('الطلبات', rows.length.toString(), Icons.event_available_outlined),
          _SummaryData('المعتمدة', rows.where((row) => row.data['status'] == 'approved').length.toString(), Icons.check_circle_outline),
          _SummaryData('المعلقة', rows.where((row) => row.data['status'] == 'pending').length.toString(), Icons.pending_actions_outlined),
        ],
      ReportKind.overtime => [
          _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
          _SummaryData('الساعات', (rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'overtime_minutes')) / 60).toStringAsFixed(1), Icons.timer_outlined),
          _SummaryData('القيمة', _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'overtime_amount'))), Icons.payments_outlined),
        ],
      ReportKind.documents => [
          _SummaryData('المستندات', rows.length.toString(), Icons.folder_copy_outlined),
          _SummaryData('لها ملف', rows.where((row) => row.data['file_id'] != null).length.toString(), Icons.attach_file_outlined),
        ],
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : constraints.maxWidth < 900 ? 3 : 4;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: width, child: _SummaryCard(data: card)))
              .toList(),
        );
      },
    );
  }

  Widget _rowTile(models.Row row, Map<String, String> employeeNames) {
    final data = row.data;
    final employee = employeeNames[data['employee_id']] ?? data['employee_id'] ?? '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_meta.icon, size: 20)),
        title: Text(_title(data), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('الموظف: $employee\n${_subtitle(data)}', maxLines: 3, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Text(_trailing(data), textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  String _title(Map<String, dynamic> data) => switch (widget.kind) {
        ReportKind.attendance => 'تاريخ الدوام: ${_dateValue(data['work_date'])}',
        ReportKind.payroll => '${data['period_name'] ?? 'مسير راتب'} - صافي ${_money(_num(data, 'net_salary'))}',
        ReportKind.advances => 'سلفة ${_money(_num(data, 'principal_amount'))}',
        ReportKind.penalties => '${data['category'] ?? 'جزاء'}',
        ReportKind.leaves => '${data['leave_type'] ?? 'إجازة'}',
        ReportKind.overtime => 'عمل إضافي ${(_num(data, 'overtime_minutes') / 60).toStringAsFixed(1)} ساعة',
        ReportKind.documents => '${data['title'] ?? data['document_type'] ?? data['file_name'] ?? 'مستند'}',
      };

  String _subtitle(Map<String, dynamic> data) => switch (widget.kind) {
        ReportKind.attendance => 'دخول: ${_dateValue(data['check_in'])} | خروج: ${_dateValue(data['check_out'])} | ساعات: ${(_num(data, 'worked_minutes') / 60).toStringAsFixed(1)}',
        ReportKind.payroll => 'أساسي: ${_money(_num(data, 'base_salary'))} | إضافات: ${_money(_num(data, 'allowances') + _num(data, 'bonuses') + _num(data, 'overtime_amount'))} | خصومات: ${_money(_num(data, 'absence_deductions') + _num(data, 'late_deductions') + _num(data, 'penalties_amount') + _num(data, 'advance_installments') + _num(data, 'other_deductions'))}',
        ReportKind.advances => 'التاريخ: ${_dateValue(data['created_at'])} | القسط: ${_money(_num(data, 'installment_amount'))} | المتبقي: ${_money(_num(data, 'remaining_amount'))}',
        ReportKind.penalties => 'التاريخ: ${_dateValue(data['penalty_date'])} | السبب: ${data['reason'] ?? '-'} | القيمة: ${_money(_num(data, 'amount'))}',
        ReportKind.leaves => 'من ${_dateValue(data['start_date'])} إلى ${_dateValue(data['end_date'])} | السبب: ${data['reason'] ?? '-'}',
        ReportKind.overtime => 'التاريخ: ${_dateValue(data['work_date'])} | القيمة: ${_money(_num(data, 'overtime_amount'))} | الدفع: ${data['payment_status'] ?? '-'}',
        ReportKind.documents => 'النوع: ${data['document_type'] ?? '-'} | الملف: ${data['file_name'] ?? data['file_id'] ?? '-'}',
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

class _ReportHeader extends StatelessWidget {
  final _ReportMeta meta;

  const _ReportHeader({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 24, child: Icon(meta.icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(meta.description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  const _DateFilterButton({required this.label, required this.value, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, size: 22),
            const SizedBox(height: 8),
            Text(data.value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(data.title, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryData(this.title, this.value, this.icon);
}

class _ReportMeta {
  final String title;
  final String description;
  final IconData icon;

  const _ReportMeta({required this.title, required this.description, required this.icon});
}

enum _PeriodPreset { today, thisWeek, thisMonth, lastMonth }

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StateMessage({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
