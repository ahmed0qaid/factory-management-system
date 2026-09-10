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
import '../../services/report_pdf_service.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/employee_picker_field.dart';

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
  _PeriodPreset? _selectedPreset;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _service.getEmployees(limit: 500);
  }

  void _loadReport() {
    final employeeId = _selectedEmployeeId;
    if (employeeId == null) {
      _showMessage('اختر الموظف أولًا.');
      return;
    }
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      _showMessage('تاريخ البداية يجب أن يسبق تاريخ النهاية.');
      return;
    }

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
      _selectedPreset = null;
      _reportFuture = null;
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _applyPreset(_PeriodPreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late DateTime from;
    late DateTime to;
    switch (preset) {
      case _PeriodPreset.thisMonth:
        from = DateTime(today.year, today.month, 1);
        to = today;
      case _PeriodPreset.lastMonth:
        from = DateTime(today.year, today.month - 1, 1);
        to = DateTime(today.year, today.month, 0);
      case _PeriodPreset.last30Days:
        from = today.subtract(const Duration(days: 29));
        to = today;
      case _PeriodPreset.thisYear:
        from = DateTime(today.year, 1, 1);
        to = today;
    }
    setState(() {
      _selectedPreset = preset;
      _from = from;
      _to = to;
      _reportFuture = null;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedEmployeeId = null;
      _from = null;
      _to = null;
      _selectedPreset = null;
      _reportFuture = null;
    });
  }

  String _date(DateTime? value) {
    if (value == null) return '-';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '-';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_date(value)} $hour:$minute';
  }

  String _money(num value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

  Future<void> _handleExport(_ExportAction action) async {
    if (_exporting) return;
    final future = _reportFuture;
    if (future == null) {
      _showMessage('اعرض تقرير الموظف أولًا قبل التصدير.');
      return;
    }

    setState(() => _exporting = true);
    try {
      final report = await future;
      final payload = _buildPdfPayload(report);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (action == _ExportAction.pdf) {
        await ReportPdfService.share(
          payload: payload,
          fileName: 'employee_full_report_$timestamp.pdf',
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _status(String value) {
    switch (value) {
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
      case 'draft':
        return 'مسودة';
      default:
        return value;
    }
  }

  ReportPdfPayload _buildPdfPayload(EmployeeFullReport report) {
    final employee = report.employee;
    final period =
        'الفترة: من ${_from == null ? 'البداية' : _date(_from)} إلى ${_to == null ? 'اليوم' : _date(_to)}';

    return ReportPdfPayload(
      title: 'التقرير الشامل للموظف',
      subtitle: '${employee.fullName} - ${employee.employeeNumber}',
      filterSummary: period,
      metrics: [
        ReportPdfMetric(label: 'أيام الحضور', value: report.presentDays.toString()),
        ReportPdfMetric(label: 'أيام الغياب', value: report.absentDays.toString()),
        ReportPdfMetric(label: 'مرات التأخير', value: report.lateCount.toString()),
        ReportPdfMetric(label: 'إجمالي الرواتب', value: _money(report.totalPayroll)),
        ReportPdfMetric(label: 'إجمالي السلف', value: _money(report.totalAdvances)),
        ReportPdfMetric(label: 'السلف المتبقية', value: _money(report.remainingAdvances)),
        ReportPdfMetric(label: 'إجمالي الجزاءات', value: _money(report.totalPenalties)),
        ReportPdfMetric(label: 'إجمالي الإضافي', value: _money(report.totalOvertime)),
      ],
      sections: [
        ReportPdfSection(
          title: 'بيانات الموظف',
          lines: [
            ReportPdfLine(
              title: 'الاسم: ${employee.fullName}',
              subtitle:
                  'الرقم الوظيفي: ${employee.employeeNumber} | القسم: ${employee.departmentName ?? '-'} | المسمى: ${employee.jobTitleName ?? '-'}',
              trailing: employee.active ? 'نشط' : 'موقوف',
            ),
          ],
        ),
        ReportPdfSection(
          title: 'الحضور والانصراف (${report.attendance.length})',
          lines: report.attendance
              .map(
                (row) => ReportPdfLine(
                  title: _date(row.workDate),
                  subtitle:
                      'دخول: ${_dateTime(row.checkIn)} | خروج: ${_dateTime(row.checkOut)} | ساعات: ${(row.workedMinutes / 60).toStringAsFixed(1)}',
                  trailing: _status(row.status),
                ),
              )
              .toList(),
        ),
        ReportPdfSection(
          title: 'الرواتب (${report.payroll.length})',
          lines: report.payroll
              .map(
                (row) => ReportPdfLine(
                  title: 'صافي الراتب: ${_money(row.netSalary)}',
                  subtitle:
                      'أساسي: ${_money(row.baseSalary)} | إضافات: ${_money(row.allowances + row.bonuses + row.overtimeAmount)} | خصومات: ${_money(row.absenceDeductions + row.lateDeductions + row.penaltiesAmount + row.advanceInstallments + row.otherDeductions)}',
                  trailing: _status(row.status),
                ),
              )
              .toList(),
        ),
        ReportPdfSection(
          title: 'السلف (${report.advances.length})',
          lines: report.advances
              .map(
                (row) => ReportPdfLine(
                  title: 'السلفة: ${_money(row.principalAmount)}',
                  subtitle:
                      'التاريخ: ${_date(row.requestDate)} | القسط: ${_money(row.installmentAmount)} | المتبقي: ${_money(row.remainingAmount)}',
                  trailing: _status(row.status),
                ),
              )
              .toList(),
        ),
        ReportPdfSection(
          title: 'الجزاءات (${report.penalties.length})',
          lines: report.penalties
              .map(
                (row) => ReportPdfLine(
                  title: row.category,
                  subtitle: '${_date(row.penaltyDate)} | ${row.reason}',
                  trailing: _money(row.amount),
                ),
              )
              .toList(),
        ),
        ReportPdfSection(
          title: 'الإجازات (${report.leaves.length})',
          lines: report.leaves
              .map(
                (row) => ReportPdfLine(
                  title: row.leaveType,
                  subtitle: '${_date(row.startDate)} إلى ${_date(row.endDate)}',
                  trailing: _status(row.status),
                ),
              )
              .toList(),
        ),
        ReportPdfSection(
          title: 'العمل الإضافي (${report.overtime.length})',
          lines: report.overtime
              .map(
                (row) => ReportPdfLine(
                  title: '${(row.overtimeMinutes / 60).toStringAsFixed(1)} ساعة',
                  subtitle:
                      '${_date(row.workDate)} | الدفع: ${_status(row.paymentStatus)}',
                  trailing: row.overtimeAmount == null
                      ? _status(row.approvalStatus)
                      : _money(row.overtimeAmount!),
                ),
              )
              .toList(),
        ),
        ReportPdfSection(
          title: 'مستندات الموظف (${report.documents.length})',
          lines: report.documents
              .map(
                (row) => ReportPdfLine(
                  title:
                      '${row.data['title'] ?? row.data['document_type'] ?? row.$id}',
                  subtitle: '${row.data['file_name'] ?? row.data['notes'] ?? ''}',
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'التقرير الشامل للموظف',
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
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 650 ? 10 : 16,
                ),
                children: [
                  _filters(employees),
                  const SizedBox(height: 12),
                  if (_reportFuture == null)
                    const _StateMessage(
                      icon: Icons.person_search_outlined,
                      title: 'اختر الموظف والفترة',
                      message:
                          'ابحث عن الموظف بالاسم أو الرقم الوظيفي، ثم حدد الفترة واضغط عرض التقرير.',
                    )
                  else
                    FutureBuilder<EmployeeFullReport>(
                      future: _reportFuture,
                      builder: (context, reportSnapshot) {
                        if (!reportSnapshot.hasData && !reportSnapshot.hasError) {
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
            final compact = constraints.maxWidth < 620;
            final picker = EmployeePickerField(
              employees: employees,
              selectedEmployeeId: _selectedEmployeeId,
              labelText: 'الموظف',
              onChanged: (value) {
                setState(() {
                  _selectedEmployeeId = value;
                  _reportFuture = null;
                });
              },
            );
            final fromButton = _DateButton(
              label: 'من تاريخ',
              value: _from == null ? 'غير محدد' : _date(_from),
              icon: Icons.date_range_outlined,
              onPressed: () => _pickDate(true),
            );
            final toButton = _DateButton(
              label: 'إلى تاريخ',
              value: _to == null ? 'غير محدد' : _date(_to),
              icon: Icons.event_outlined,
              onPressed: () => _pickDate(false),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إعداد التقرير',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (compact) ...[
                  picker,
                  const SizedBox(height: 10),
                  fromButton,
                  const SizedBox(height: 8),
                  toButton,
                ] else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: 380, child: picker),
                      SizedBox(width: 190, child: fromButton),
                      SizedBox(width: 190, child: toButton),
                    ],
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip(_PeriodPreset.thisMonth, 'هذا الشهر'),
                    _presetChip(_PeriodPreset.lastMonth, 'الشهر السابق'),
                    _presetChip(_PeriodPreset.last30Days, 'آخر 30 يومًا'),
                    _presetChip(_PeriodPreset.thisYear, 'هذه السنة'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loadReport,
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('عرض التقرير'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'مسح الاختيارات',
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _presetChip(_PeriodPreset preset, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedPreset == preset,
      onSelected: (_) => _applyPreset(preset),
    );
  }

  Widget _report(EmployeeFullReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
    final details = [
      _Info('الرقم الوظيفي', employee.employeeNumber),
      _Info('القسم', employee.departmentName ?? '-'),
      _Info('المسمى الوظيفي', employee.jobTitleName ?? '-'),
      _Info('الهاتف', employee.phone ?? '-'),
      _Info('تاريخ التعيين', _date(employee.hireDate)),
      _Info('الراتب الأساسي', _money(employee.baseSalary)),
      _Info('المكافأة الشهرية', _money(employee.monthlyBonus)),
      _Info('الحالة', employee.active ? 'نشط' : 'موقوف'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(employee.fullName.isEmpty ? 'م' : employee.fullName[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(employee.roleLabel),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 520
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: details
                      .map(
                        (info) => SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                info.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(EmployeeFullReport report) {
    final items = [
      _SummaryData('أيام الحضور', report.presentDays.toString(), Icons.check_circle_outline),
      _SummaryData('أيام الغياب', report.absentDays.toString(), Icons.cancel_outlined),
      _SummaryData('مرات التأخير', report.lateCount.toString(), Icons.schedule_outlined),
      _SummaryData('إجمالي الرواتب', _money(report.totalPayroll), Icons.payments_outlined),
      _SummaryData('إجمالي السلف', _money(report.totalAdvances), Icons.account_balance_wallet_outlined),
      _SummaryData('السلف المتبقية', _money(report.remainingAdvances), Icons.pending_actions_outlined),
      _SummaryData('إجمالي الجزاءات', _money(report.totalPenalties), Icons.gavel_outlined),
      _SummaryData('إجمالي الإضافي', _money(report.totalOvertime), Icons.timer_outlined),
    ];
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
          children: items
              .map((item) => SizedBox(width: width, child: _SummaryCard(data: item)))
              .toList(),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required int count,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(count == 0 ? 'لا توجد بيانات' : '$count سجل'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _attendance(List<AttendanceRecordModel> rows) {
    if (rows.isEmpty) return const _EmptyLine('لا توجد سجلات حضور لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => _RecordTile(
              icon: Icons.calendar_today_outlined,
              title: _date(row.workDate),
              subtitle:
                  'دخول: ${_dateTime(row.checkIn)}\nخروج: ${_dateTime(row.checkOut)} • ساعات: ${(row.workedMinutes / 60).toStringAsFixed(1)}',
              trailing: _status(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _payroll(List<PayrollRecordModel> rows) {
    if (rows.isEmpty) return const _EmptyLine('لا توجد سجلات رواتب لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => _RecordTile(
              icon: Icons.payments_outlined,
              title: 'الصافي: ${_money(row.netSalary)}',
              subtitle:
                  'أساسي: ${_money(row.baseSalary)} • إضافات: ${_money(row.allowances + row.bonuses + row.overtimeAmount)}\nخصومات: ${_money(row.absenceDeductions + row.lateDeductions + row.penaltiesAmount + row.advanceInstallments + row.otherDeductions)}',
              trailing: _status(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _advances(List<AdvanceModel> rows) {
    if (rows.isEmpty) return const _EmptyLine('لا توجد سلف لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => _RecordTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'السلفة: ${_money(row.principalAmount)}',
              subtitle:
                  'التاريخ: ${_date(row.requestDate)} • القسط: ${_money(row.installmentAmount)}\nالمتبقي: ${_money(row.remainingAmount)}',
              trailing: _status(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _penalties(List<PenaltyModel> rows) {
    if (rows.isEmpty) return const _EmptyLine('لا توجد جزاءات لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => _RecordTile(
              icon: Icons.gavel_outlined,
              title: row.category,
              subtitle: '${_date(row.penaltyDate)}\n${row.reason}',
              trailing: _money(row.amount),
            ),
          )
          .toList(),
    );
  }

  Widget _leaves(List<LeaveModel> rows) {
    if (rows.isEmpty) return const _EmptyLine('لا توجد إجازات لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => _RecordTile(
              icon: Icons.event_available_outlined,
              title: row.leaveType,
              subtitle:
                  '${_date(row.startDate)} إلى ${_date(row.endDate)}${row.reason?.trim().isNotEmpty == true ? '\n${row.reason}' : ''}',
              trailing: _status(row.status),
            ),
          )
          .toList(),
    );
  }

  Widget _overtime(List<OvertimeRecordModel> rows) {
    if (rows.isEmpty) return const _EmptyLine('لا توجد سجلات عمل إضافي لهذه الفترة.');
    return Column(
      children: rows
          .map(
            (row) => _RecordTile(
              icon: Icons.timer_outlined,
              title: '${(row.overtimeMinutes / 60).toStringAsFixed(1)} ساعة',
              subtitle:
                  '${_date(row.workDate)} • الدفع: ${_status(row.paymentStatus)}',
              trailing: row.overtimeAmount == null
                  ? _status(row.approvalStatus)
                  : _money(row.overtimeAmount!),
            ),
          )
          .toList(),
    );
  }

  Widget _documents(EmployeeFullReport report) {
    if (report.documents.isEmpty) {
      return const _EmptyLine('لا توجد مستندات لهذا الموظف.');
    }
    return Column(
      children: report.documents
          .map(
            (row) => _RecordTile(
              icon: Icons.description_outlined,
              title: '${row.data['title'] ?? row.data['document_type'] ?? row.$id}',
              subtitle: '${row.data['file_name'] ?? row.data['notes'] ?? ''}',
            ),
          )
          .toList(),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  const _DateButton({
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
            Icon(data.icon, size: 21),
            const SizedBox(height: 7),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  const _RecordTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(child: Icon(icon, size: 19)),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: trailing == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                trailing!,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String message;

  const _EmptyLine(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, textAlign: TextAlign.center),
    );
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

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryData(this.title, this.value, this.icon);
}

class _Info {
  final String label;
  final String value;

  const _Info(this.label, this.value);
}

enum _PeriodPreset { thisMonth, lastMonth, last30Days, thisYear }
enum _ExportAction { pdf, print }
