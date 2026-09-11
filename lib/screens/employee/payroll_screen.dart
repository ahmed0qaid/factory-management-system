import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/payroll_model.dart';
import '../../services/employee_service.dart';
import '../../services/pdf_service.dart';
import '../../services/salary_calculation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_status_pill.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _service = EmployeeService();

  late int _selectedYear;
  late int _selectedMonth;

  bool _hasSelectedPeriod = false;
  Future<List<dynamic>>? _dataFuture;
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  void _fetchData() {
    setState(() {
      _hasSelectedPeriod = true;
      _detailsExpanded = false;
      _dataFuture = Future.wait([
        _service.getSalaryReportForMonth(
          year: _selectedYear,
          month: _selectedMonth,
        ),
        _service.getMyPayroll(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
      children: [
        _buildPeriodSelector(),
        if (_hasSelectedPeriod && _dataFuture != null) ...[
          const SizedBox(height: 16),
          FutureBuilder<List<dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('حدث خطأ: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final currentReport = snapshot.data![0] as MonthlySalaryReport;
              final items = snapshot.data![1] as List<PayrollRecordModel>;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCurrentMonthTitleCard(currentReport),
                  const SizedBox(height: 16),
                  _buildCurrentMonthSummaryCard(currentReport),
                  const SizedBox(height: 16),
                  _buildCurrentMonthDetailsCard(currentReport),
                  const SizedBox(height: 24),
                  const Text(
                    'كشوف الرواتب المعتمدة السابقة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('لا توجد كشوف رواتب معتمدة سابقة'),
                      ),
                    )
                  else
                    ...items.map((item) => _buildPayrollCard(item)),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final now = DateTime.now();
    final currentYear = now.year;
    final years = List.generate(
      (currentYear - 2020) + 2,
      (index) => 2020 + index,
    ).reversed.toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اختيار الفترة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'السنة',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<int>(
                      value: _selectedYear,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: years.map((y) {
                        return DropdownMenuItem(
                          value: y,
                          child: Text(y.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedYear = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الشهر',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<int>(
                      value: _selectedMonth,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: List.generate(12, (index) {
                        final monthNum = index + 1;
                        return DropdownMenuItem(
                          value: monthNum,
                          child: Text(_getMonthName(monthNum)),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMonth = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('عرض الراتب', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMonthTitleCard(MonthlySalaryReport report) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Text(
              'راتب ${_getMonthName(report.month)} ${report.year}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'حساب تقديري غير معتمد',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMonthSummaryCard(MonthlySalaryReport report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ملخص الراتب',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSalaryMetricCard(
                  title: 'الاستحقاق الكلي',
                  value: Formatters.money(report.grossSalary),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSalaryMetricCard(
                  title: 'الراتب حتى الآن',
                  value: Formatters.money(report.attendanceSalary),
                  icon: Icons.how_to_reg_outlined,
                  iconColor: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryMetricCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: iconColor ?? Colors.grey[600]),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMonthDetailsCard(MonthlySalaryReport report) {
    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            _detailsExpanded ? 'إخفاء التفاصيل' : 'عرض التفاصيل',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _detailsExpanded = expanded;
            });
          },
          children: [
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'تفاصيل الراتب',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            _buildInfoRow('الراتب الأساسي', Formatters.money(report.baseSalary)),
            _buildInfoRow('المكافأة الشهرية', Formatters.money(report.monthlyBonus)),
            _buildInfoRow('أجر اليوم', Formatters.money(report.dailyWage)),
            _buildInfoRow('أجر الساعة', Formatters.money(report.hourlyWage)),
            _buildInfoRow('ساعات العمل اليومية', report.dailyWorkHours.toString()),
            const SizedBox(height: 8),
            _buildInfoRow('أيام الحضور', report.presentDays.toString(), color: Colors.green),
            _buildInfoRow('أيام الغياب', report.absentDays.toString(), color: Colors.red),
            const SizedBox(height: 8),
            _buildInfoRow('خصم الغياب', Formatters.money(report.absenceDeduction), color: Colors.red),
            _buildInfoRow('خصم الجزاءات', Formatters.money(report.penaltiesDeduction), color: Colors.red),
            _buildInfoRow('خصم السلف', Formatters.money(report.advanceDeduction), color: Colors.red),
            const SizedBox(height: 8),
            _buildInfoRow('طريقة الجمعة', report.fridayMode.label),
            _buildInfoRow('أيام الشهر', report.daysInMonth.toString()),
            _buildInfoRow('أيام الجمعة', report.fridaysCount.toString()),
            _buildInfoRow('أيام الراتب المعتمدة', report.salaryDays.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollCard(PayrollRecordModel item) {
    final negative = item.netSalary < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Formatters.date(item.createdAt),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                AppStatusPill(
                  label: item.status == 'paid' ? 'مدفوع' : item.status == 'approved' ? 'معتمد' : 'قيد المراجعة',
                  color: item.status == 'paid' ? AppColors.success : item.status == 'approved' ? AppColors.primary : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('الراتب الأساسي', Formatters.money(item.baseSalary)),
            _buildInfoRow('المكافأة الشهرية', Formatters.money(item.monthlyBonus)),
            _buildInfoRow('المستحق الشهري', Formatters.money(item.monthlyEntitlement)),
            const Divider(),
            _buildInfoRow('البدلات', Formatters.money(item.allowances)),
            _buildInfoRow('الإضافي', Formatters.money(item.overtimeAmount)),
            _buildInfoRow('مكافآت إضافية', Formatters.money(item.bonuses)),
            const Divider(),
            _buildInfoRow('خصم الغياب', Formatters.money(-item.absenceDeductions)),
            _buildInfoRow('خصم التأخير', Formatters.money(-item.lateDeductions)),
            _buildInfoRow('الجزاءات', Formatters.money(-item.penaltiesAmount)),
            _buildInfoRow('خصم السلف', Formatters.money(-item.advanceInstallments)),
            _buildInfoRow('خصومات أخرى', Formatters.money(-item.otherDeductions)),
            const Divider(),
            _buildInfoRow(
              'صافي الراتب',
              Formatters.money(item.netSalary),
              isBold: true,
              color: negative ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final profile = await _service.getMyProfile();
                    final pdfBytes = await PdfService.generatePayslip(
                      employeeName: profile.fullName,
                      employeeNumber: profile.employeeNumber,
                      jobTitle: profile.role,
                      period: Formatters.date(item.createdAt),
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
                      filename: 'payslip_${item.createdAt}.pdf',
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في توليد الـ PDF: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تحميل كشف الراتب PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    if (month >= 1 && month <= 12) return names[month];
    return month.toString();
  }
}
