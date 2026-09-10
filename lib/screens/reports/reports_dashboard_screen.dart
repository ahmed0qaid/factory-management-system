import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../widgets/common/app_scaffold.dart';
import 'employee_full_report_screen.dart';
import 'report_list_screen.dart';

class ReportsDashboardScreen extends StatelessWidget {
  final ProfileModel currentProfile;

  const ReportsDashboardScreen({super.key, required this.currentProfile});

  @override
  Widget build(BuildContext context) {
    final reports = [
      _ReportEntry(
        title: 'التقرير الشامل للموظف',
        icon: Icons.badge_outlined,
        enabled: AppRoles.canViewEmployeeFullReport(currentProfile.role),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                EmployeeFullReportScreen(currentProfile: currentProfile),
          ),
        ),
      ),
      _ReportEntry(
        title: 'تقارير الحضور والانصراف',
        icon: Icons.calendar_month_outlined,
        enabled: AppRoles.canViewAttendanceReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.attendance),
      ),
      _ReportEntry(
        title: 'تقارير الرواتب',
        icon: Icons.payments_outlined,
        enabled: AppRoles.canViewPayrollReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.payroll),
      ),
      _ReportEntry(
        title: 'تقارير السلف',
        icon: Icons.account_balance_wallet_outlined,
        enabled: AppRoles.canViewAdvancesReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.advances),
      ),
      _ReportEntry(
        title: 'تقارير الجزاءات',
        icon: Icons.gavel_outlined,
        enabled: AppRoles.canViewPenaltiesReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.penalties),
      ),
      _ReportEntry(
        title: 'تقارير الإجازات',
        icon: Icons.event_available_outlined,
        enabled: AppRoles.canViewLeavesReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.leaves),
      ),
      _ReportEntry(
        title: 'تقارير العمل الإضافي',
        icon: Icons.timer_outlined,
        enabled: AppRoles.canViewOvertimeReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.overtime),
      ),
      _ReportEntry(
        title: 'تقارير مستندات الموظفين',
        icon: Icons.folder_copy_outlined,
        enabled: AppRoles.canViewDocumentReports(currentProfile.role),
        onTap: () => _openList(context, ReportKind.documents),
      ),
    ];

    return AppScaffold(
      title: 'لوحة التقارير',
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 150,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return Card(
            child: InkWell(
              onTap: report.enabled ? report.onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(report.icon, size: 32),
                    const Spacer(),
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(report.enabled ? 'متاح' : 'غير متاح لهذا الدور'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openList(BuildContext context, ReportKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReportListScreen(currentProfile: currentProfile, kind: kind),
      ),
    );
  }
}

class _ReportEntry {
  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _ReportEntry({
    required this.title,
    required this.icon,
    this.enabled = false,
    this.onTap,
  });
}
