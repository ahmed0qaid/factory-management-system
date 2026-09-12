import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/employee_report_service.dart';
import '../../services/report_pdf_service.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/employee_picker_field.dart';

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
  List<ProfileModel> _employees = const [];
  String? _selectedEmployeeId;
  DateTime? _from;
  DateTime? _to;
  _PeriodPreset? _selectedPreset;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
    _loadRows();
  }

  Future<List<ProfileModel>> _loadEmployees() async {
    final employees = await _service.getEmployees(limit: 500);
    if (mounted) setState(() => _employees = employees);
    return employees;
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

  Future<List<models.Row>> _fetchRows() => switch (widget.kind) {
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

  void _loadRows() {
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      _showMessage('تاريخ البداية يجب أن يسبق تاريخ النهاية.');
      return;
    }
    setState(() => _rowsFuture = _fetchRows());
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
    late DateTime from;
    late DateTime to;

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
        from = DateTime(today.year, today.month - 1, 1);
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
    _loadRows();
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

  ProfileModel? get _selectedEmployee {
    final id = _selectedEmployeeId;
    if (id == null) return null;
    for (final employee in _employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  Future<void> _handleExport(_ExportAction action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = await _fetchRows();
      if (rows.isEmpty) {
        _showMessage('لا توجد بيانات حالية لتصديرها.');
        return;
      }
      final payload = _buildPdfPayload(rows);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (action == _ExportAction.pdf) {
        await ReportPdfService.share(
          payload: payload,
          fileName: 'report_${widget.kind.name}_$stamp.pdf',
        );
      } else {
        await ReportPdfService.printReport(payload);
      }
    } catch (error) {
      _showMessage('تعذر تجهيز التقرير: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  ReportPdfPayload _buildPdfPayload(List<models.Row> rows) {
    final employee = _selectedEmployee;
    final period = widget.kind == ReportKind.documents
        ? null
        : 'الفترة: من ${_from == null ? 'البداية' : _date(_from)} إلى ${_to == null ? 'اليوم' : _date(_to)}';
    final employeeText = employee == null
        ? 'كل الموظفين'
        : '${employee.fullName} - ${employee.employeeNumber}';

    return ReportPdfPayload(
      title: 'تقرير ${_meta.title}',
      subtitle: employeeText,
      filterSummary: period,
      metrics: _summaryData(rows)
          .map((item) => ReportPdfMetric(label: item.title, value: item.value))
          .toList(),
      sections: [
        ReportPdfSection(
          title: 'تفاصيل السجلات (${rows.length})',
          lines: rows
              .map(
                (row) => ReportPdfLine(
                  title: _title(row.data),
                  subtitle:
                      '${_employeeName(row.data['employee_id'])}\n${_subtitle(row.data)}',
                  trailing: _localizedStatus(_trailing(row.data)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _employeeName(dynamic id) {
    final value = id?.toString();
    if (value == null || value.isEmpty) return 'الموظف: غير محدد';
    for (final employee in _employees) {
      if (employee.id == value) {
        return 'الموظف: ${employee.fullName} (${employee.employeeNumber})';
      }
    }
    return 'الموظف: $value';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final compact = MediaQuery.sizeOf(context).width < 650;

    return AppScaffold(
      title: 'تقرير ${meta.title}',
      actions: [
        if (_exporting)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          PopupMenuButton<_ExportAction>(
            tooltip: 'تصدير وطباعة',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: _handleExport,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ExportAction.pdf,
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('مشاركة / حفظ PDF'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: _ExportAction.print,
                child: ListTile(
                  leading: Icon(Icons.print_outlined),
                  title: Text('طباعة التقرير'),
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                          message:
                              _selectedEmployeeId == null &&
                                  _from == null &&
                                  _to == null
                              ? 'لا توجد سجلات متاحة حاليًا لهذا التقرير.'
                              : 'لا توجد سجلات مطابقة للفلاتر المحددة. جرّب تغيير الموظف أو الفترة.',
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _summary(rows),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'تفاصيل السجلات',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text('${rows.length} سجل'),
                            ],
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
            final employeeField = EmployeePickerField(
              employees: employees,
              selectedEmployeeId: _selectedEmployeeId,
              allowAll: true,
              labelText: 'الموظف',
              onChanged: (value) {
                setState(() => _selectedEmployeeId = value);
                _loadRows();
              },
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
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث التقرير'),
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
                Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'تصفية التقرير',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (compact) ...[
                  employeeField,
                  if (dateControls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...dateControls.expand(
                      (widget) => [widget, const SizedBox(height: 8)],
                    ),
                    _periodPresets(),
                  ],
                  const SizedBox(height: 12),
                  actions,
                ] else ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(width: 360, child: employeeField),
                      ...dateControls.map(
                        (widget) => SizedBox(width: 190, child: widget),
                      ),
                    ],
                  ),
                  if (dateControls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _periodPresets(),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(width: 360, child: actions),
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

  List<_SummaryData> _summaryData(
    List<models.Row> rows,
  ) => switch (widget.kind) {
    ReportKind.attendance => [
      _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
      _SummaryData(
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
      _SummaryData(
        'الغياب',
        rows.where((row) => row.data['status'] == 'absent').length.toString(),
        Icons.cancel_outlined,
      ),
      _SummaryData(
        'التأخير',
        rows
            .where((row) => _num(row.data, 'late_minutes') > 0)
            .length
            .toString(),
        Icons.schedule_outlined,
      ),
    ],
    ReportKind.payroll => [
      _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
      _SummaryData(
        'صافي الرواتب',
        _money(
          rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'net_salary')),
        ),
        Icons.payments_outlined,
      ),
      _SummaryData(
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
      _SummaryData(
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
      _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
      _SummaryData(
        'إجمالي السلف',
        _money(
          rows.fold<num>(
            0,
            (sum, row) => sum + _num(row.data, 'principal_amount'),
          ),
        ),
        Icons.account_balance_wallet_outlined,
      ),
      _SummaryData(
        'المتبقي',
        _money(
          rows.fold<num>(
            0,
            (sum, row) => sum + _num(row.data, 'remaining_amount'),
          ),
        ),
        Icons.pending_actions_outlined,
      ),
    ],
    ReportKind.penalties => [
      _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
      _SummaryData(
        'إجمالي الجزاءات',
        _money(rows.fold<num>(0, (sum, row) => sum + _num(row.data, 'amount'))),
        Icons.gavel_outlined,
      ),
      _SummaryData(
        'دقائق الخصم',
        rows
            .fold<num>(
              0,
              (sum, row) => sum + _num(row.data, 'minutes_deducted'),
            )
            .toString(),
        Icons.timer_off_outlined,
      ),
    ],
    ReportKind.leaves => [
      _SummaryData(
        'الطلبات',
        rows.length.toString(),
        Icons.event_available_outlined,
      ),
      _SummaryData(
        'المعتمدة',
        rows.where((row) => row.data['status'] == 'approved').length.toString(),
        Icons.check_circle_outline,
      ),
      _SummaryData(
        'المعلقة',
        rows.where((row) => row.data['status'] == 'pending').length.toString(),
        Icons.pending_actions_outlined,
      ),
    ],
    ReportKind.overtime => [
      _SummaryData('السجلات', rows.length.toString(), Icons.list_alt_outlined),
      _SummaryData(
        'الساعات',
        (rows.fold<num>(
                  0,
                  (sum, row) => sum + _num(row.data, 'overtime_minutes'),
                ) /
                60)
            .toStringAsFixed(1),
        Icons.timer_outlined,
      ),
      _SummaryData(
        'القيمة',
        _money(
          rows.fold<num>(
            0,
            (sum, row) => sum + _num(row.data, 'overtime_amount'),
          ),
        ),
        Icons.payments_outlined,
      ),
    ],
    ReportKind.documents => [
      _SummaryData(
        'المستندات',
        rows.length.toString(),
        Icons.folder_copy_outlined,
      ),
      _SummaryData(
        'لها ملف',
        rows.where((row) => row.data['file_id'] != null).length.toString(),
        Icons.attach_file_outlined,
      ),
    ],
  };

  Widget _summary(List<models.Row> rows) {
    final cards = _summaryData(rows);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth < 900
            ? 3
            : 4;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: _SummaryCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _rowTile(models.Row row, Map<String, String> employeeNames) {
    final data = row.data;
    final employee =
        employeeNames[data['employee_id']] ?? data['employee_id'] ?? '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_meta.icon, size: 20)),
        title: Text(_title(data), maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'الموظف: $employee\n${_subtitle(data)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 92),
          child: Text(
            _localizedStatus(_trailing(data)),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
      'التاريخ: ${_dateValue(data['work_date'])} | القيمة: ${_money(_num(data, 'overtime_amount'))} | الدفع: ${_localizedStatus('${data['payment_status'] ?? '-'}')}',
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

  String _localizedStatus(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
        return 'قيد المراجعة';
      case 'paid':
        return 'مدفوع';
      case 'unpaid':
        return 'غير مدفوع';
      case 'active':
        return 'نشط';
      case 'closed':
        return 'مغلق';
      default:
        return status;
    }
  }
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
                  Text(
                    meta.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
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
            Text(
              data.value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              data.title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
  const _ReportMeta({
    required this.title,
    required this.description,
    required this.icon,
  });
}

enum _PeriodPreset { today, thisWeek, thisMonth, lastMonth }

enum _ExportAction { pdf, print }

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
