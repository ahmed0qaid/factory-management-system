import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/payroll_model.dart';
import '../../services/employee_service.dart';
import '../../services/pdf_service.dart';
import '../../services/salary_calculation_service.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_status_pill.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _service = EmployeeService();
  final Map<String, Future<_PayrollPeriodViewData>> _periodCache = {};

  late int _selectedYear;
  int? _selectedMonth;
  late Future<List<PayrollRecordModel>> _historyFuture;
  Future<_PayrollPeriodViewData>? _periodFuture;
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _historyFuture = _service.getMyPayroll();
    _periodFuture = _loadPeriod(_selectedYear, _selectedMonth!);
  }

  String _periodKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  Future<_PayrollPeriodViewData> _loadPeriod(int year, int month) {
    final key = _periodKey(year, month);
    return _periodCache.putIfAbsent(key, () async {
      final results = await Future.wait<dynamic>([
        _service.getSalaryReportForMonth(year: year, month: month),
        _historyFuture,
      ]);
      final report = results[0] as MonthlySalaryReport;
      final history = results[1] as List<PayrollRecordModel>;
      return _PayrollPeriodViewData(
        report: report,
        officialRecord: _findOfficialRecord(history, year, month),
      );
    });
  }

  PayrollRecordModel? _findOfficialRecord(
    List<PayrollRecordModel> items,
    int year,
    int month,
  ) {
    final matches = items
        .where(
          (item) =>
              item.createdAt.year == year &&
              item.createdAt.month == month &&
              (item.status == 'approved' || item.status == 'paid'),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.isEmpty ? null : matches.first;
  }

  void _selectYear(int year) {
    if (_selectedYear == year) return;
    setState(() {
      _selectedYear = year;
      _selectedMonth = null;
      _periodFuture = null;
      _detailsExpanded = false;
    });
  }

  void _selectMonth(int month) {
    if (!_isMonthEnabled(_selectedYear, month)) return;
    setState(() {
      _selectedMonth = month;
      _detailsExpanded = false;
      _periodFuture = _loadPeriod(_selectedYear, month);
    });
  }

  bool _isMonthEnabled(int year, int month) {
    final now = DateTime.now();
    if (year < now.year) return true;
    if (year > now.year) return false;
    return month <= now.month;
  }

  Future<void> _refreshSelectedPeriod() async {
    final month = _selectedMonth;
    if (month == null) return;
    final key = _periodKey(_selectedYear, month);
    setState(() {
      _historyFuture = _service.getMyPayroll();
      _periodCache.remove(key);
      _periodFuture = _loadPeriod(_selectedYear, month);
    });
    await _periodFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshSelectedPeriod,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 84),
        children: [
          _buildYearSelector(),
          const SizedBox(height: 14),
          _buildMonthSelector(),
          const SizedBox(height: 18),
          if (_selectedMonth == null || _periodFuture == null)
            const AppEmptyState(
              title: 'اختر الشهر',
              message: 'اختر شهرًا من السنة المحددة لعرض تفاصيل الراتب.',
              icon: Icons.calendar_month_outlined,
            )
          else
            FutureBuilder<_PayrollPeriodViewData>(
              future: _periodFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const AppLoadingState(
                    label: 'جاري تحميل بيانات الراتب',
                  );
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                    title: 'تعذر تحميل الراتب',
                    message: '${snapshot.error}',
                    onRetry: () {
                      final month = _selectedMonth;
                      if (month == null) return;
                      final key = _periodKey(_selectedYear, month);
                      setState(() {
                        _periodCache.remove(key);
                        _periodFuture = _loadPeriod(_selectedYear, month);
                      });
                    },
                  );
                }
                return _buildPeriodContent(snapshot.data!);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      currentYear - 2020 + 1,
      (index) => currentYear - index,
    );
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'اختر السنة',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: years.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final year = years[index];
              return ChoiceChip(
                label: Text(year.toString()),
                selected: year == _selectedYear,
                onSelected: (_) => _selectYear(year),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'اختر الشهر',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _selectedYear.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.15,
          ),
          itemBuilder: (context, index) {
            final month = index + 1;
            final enabled = _isMonthEnabled(_selectedYear, month);
            final selected = _selectedMonth == month;
            return _MonthButton(
              label: _getMonthName(month),
              selected: selected,
              enabled: enabled,
              onTap: () => _selectMonth(month),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPeriodContent(_PayrollPeriodViewData data) {
    final report = data.report;
    final official = data.officialRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPeriodHeader(report, official),
        const SizedBox(height: 12),
        _buildCurrentMonthSummaryCard(report),
        const SizedBox(height: 12),
        _buildAttendanceSummary(report),
        const SizedBox(height: 12),
        _buildCurrentMonthDetailsCard(report),
        if (official != null) ...[
          const SizedBox(height: 14),
          _buildOfficialPayslipCard(official),
        ],
      ],
    );
  }

  Widget _buildPeriodHeader(
    MonthlySalaryReport report,
    PayrollRecordModel? official,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.payments_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'راتب ${_getMonthName(report.month)} ${report.year}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  official == null
                      ? 'حساب تقديري بناءً على البيانات المسجلة'
                      : 'يوجد كشف راتب مسجل لهذا الشهر',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          official == null
              ? AppStatusPill.warning('تقديري')
              : _payrollStatus(official.status),
        ],
      ),
    );
  }

  Widget _buildCurrentMonthSummaryCard(MonthlySalaryReport report) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final netColor = report.netSalary < 0 ? scheme.error : semantic.success;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ملخص الراتب',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSalaryMetricCard(
                  title: 'إجمالي الاستحقاق',
                  value: Formatters.money(report.grossSalary),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSalaryMetricCard(
                  title: 'صافي الراتب',
                  value: Formatters.money(report.netSalary),
                  icon: Icons.payments_outlined,
                  valueColor: netColor,
                  iconColor: netColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary(MonthlySalaryReport report) {
    return Row(
      children: [
        Expanded(
          child: _SmallStat(
            label: 'أيام الحضور',
            value: report.presentDays.toString(),
            icon: Icons.how_to_reg_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallStat(
            label: 'أيام الغياب',
            value: report.absentDays.toString(),
            icon: Icons.event_busy_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryMetricCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor ?? scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMonthDetailsCard(MonthlySalaryReport report) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            _detailsExpanded
                ? 'إخفاء تفاصيل الراتب'
                : 'عرض تفاصيل الراتب',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          onExpansionChanged: (expanded) {
            setState(() => _detailsExpanded = expanded);
          },
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),
            _buildInfoRow(
              'الراتب الأساسي',
              Formatters.money(report.baseSalary),
            ),
            _buildInfoRow(
              'المكافأة الشهرية',
              Formatters.money(report.monthlyBonus),
            ),
            _buildInfoRow('أجر اليوم', Formatters.money(report.dailyWage)),
            _buildInfoRow('أجر الساعة', Formatters.money(report.hourlyWage)),
            _buildInfoRow(
              'ساعات العمل اليومية',
              report.dailyWorkHours.toString(),
            ),
            const Divider(),
            _buildInfoRow(
              'أيام الحضور',
              report.presentDays.toString(),
              color: semantic.success,
            ),
            _buildInfoRow(
              'أيام الغياب',
              report.absentDays.toString(),
              color: scheme.error,
            ),
            const Divider(),
            _buildInfoRow(
              'خصم الغياب',
              Formatters.money(report.absenceDeduction),
              color: scheme.error,
            ),
            _buildInfoRow(
              'خصم الجزاءات',
              Formatters.money(report.penaltiesDeduction),
              color: scheme.error,
            ),
            _buildInfoRow(
              'خصم السلف',
              Formatters.money(report.advanceDeduction),
              color: scheme.error,
            ),
            const Divider(),
            _buildInfoRow('طريقة الجمعة', report.fridayMode.label),
            _buildInfoRow('أيام الشهر', report.daysInMonth.toString()),
            _buildInfoRow('أيام الجمعة', report.fridaysCount.toString()),
            _buildInfoRow(
              'أيام الراتب المعتمدة',
              report.salaryDays.toString(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialPayslipCard(PayrollRecordModel item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final netColor = item.netSalary < 0 ? scheme.error : semantic.success;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 20,
                color: semantic.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الكشف المسجل لهذا الشهر',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _payrollStatus(item.status),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'صافي الراتب المسجل',
            Formatters.money(item.netSalary),
            isBold: true,
            color: netColor,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _sharePayslip(item),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('تحميل كشف الراتب PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePayslip(PayrollRecordModel item) async {
    try {
      final profile = await _service.getMyProfile();
      final pdfBytes = await PdfService.generatePayslip(
        employeeName: profile.fullName,
        employeeNumber: profile.employeeNumber,
        jobTitle: profile.jobTitleName ?? profile.roleLabel,
        period:
            '${_getMonthName(_selectedMonth ?? item.createdAt.month)} $_selectedYear',
        baseSalary: item.baseSalary,
        monthlyBonus: item.monthlyBonus,
        monthlyEntitlement: item.monthlyEntitlement,
        overtimeAmount: item.overtimeAmount,
        allowances: item.allowances,
        bonuses: item.bonuses,
        absenceDeductions: item.absenceDeductions,
        lateDeductions: item.lateDeductions,
        penaltiesAmount: item.penaltiesAmount,
        advanceInstallments: item.advanceInstallments,
        otherDeductions: item.otherDeductions,
        netSalary: item.netSalary,
        issueDate: Formatters.date(DateTime.now()),
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'payslip_${_periodKey(_selectedYear, _selectedMonth ?? item.createdAt.month)}.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء كشف الراتب: $error')),
        );
      }
    }
  }

  AppStatusPill _payrollStatus(String status) {
    return switch (status) {
      'paid' => AppStatusPill.success('مدفوع'),
      'approved' => AppStatusPill.success('معتمد'),
      _ => AppStatusPill.warning('قيد المراجعة'),
    };
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isBold ? 16 : null,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: color ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      '',
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
    if (month >= 1 && month <= 12) return names[month];
    return month.toString();
  }
}

class _MonthButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _MonthButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = selected
        ? scheme.primaryContainer
        : enabled
            ? scheme.surfaceContainer
            : scheme.surfaceContainerLowest;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : enabled
            ? scheme.onSurface
            : scheme.onSurfaceVariant.withValues(alpha: .45);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SmallStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollPeriodViewData {
  final MonthlySalaryReport report;
  final PayrollRecordModel? officialRecord;

  const _PayrollPeriodViewData({
    required this.report,
    required this.officialRecord,
  });
}
