import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../reports/reports_dashboard_screen.dart';
import 'add_penalty_screen.dart';
import 'attendance_policy_screen.dart';
import 'create_employee_screen.dart';
import 'employee_directory_screen.dart';
import 'employee_documents_screen.dart';
import 'employee_shift_assignments_screen.dart';
import 'import_biometric_screen.dart';
import 'job_titles_screen.dart';
import 'manage_advances_screen.dart';
import 'manage_employees_screen.dart';
import 'manage_funds_screen.dart';
import 'manage_leaves_screen.dart';
import 'manage_overtime_screen.dart';
import 'manage_payroll_screen.dart';
import 'monthly_work_schedule_screen.dart';
import 'shifts_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ProfileModel profile;

  const AdminDashboardScreen({super.key, required this.profile});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminService();
  late Future<List<ProfileModel>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _service.getEmployees();
  }

  void _reload() => setState(() => _employeesFuture = _service.getEmployees());

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEmployeeScreen(currentProfile: widget.profile),
      ),
    );
    _reload();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openModule(AdminModule module) {
    switch (module.type) {
      case AdminModuleType.employees:
        if (module.manageMode) {
          _open(ManageEmployeesScreen(currentProfile: widget.profile));
        } else {
          _open(const EmployeeDirectoryScreen());
        }
      case AdminModuleType.jobTitles:
        _open(JobTitlesScreen(currentProfile: widget.profile));
      case AdminModuleType.attendancePolicy:
        _open(const AttendancePolicyScreen());
      case AdminModuleType.shifts:
        _open(ShiftsScreen(profile: widget.profile));
      case AdminModuleType.shiftAssignments:
        _open(EmployeeShiftAssignmentsScreen(profile: widget.profile));
      case AdminModuleType.monthlySchedules:
        _open(MonthlyWorkScheduleScreen(profile: widget.profile));
      case AdminModuleType.biometricImport:
        _open(ImportBiometricScreen(companyId: widget.profile.companyId));
      case AdminModuleType.overtime:
        _open(ManageOvertimeScreen(companyId: widget.profile.companyId));
      case AdminModuleType.leaves:
        _open(ManageLeavesScreen(currentProfile: widget.profile));
      case AdminModuleType.penalties:
        _open(const AddPenaltyScreen());
      case AdminModuleType.payroll:
        _open(const ManagePayrollScreen());
      case AdminModuleType.advances:
        _open(ManageAdvancesScreen(currentProfile: widget.profile));
      case AdminModuleType.funds:
        _open(ManageFundsScreen(currentProfile: widget.profile));
      case AdminModuleType.documents:
        _open(const EmployeeDocumentsScreen());
      case AdminModuleType.audit:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'سجل النظام غير مفعّل بعد، لذلك لم يتم فتح شاشة غير مكتملة.',
            ),
          ),
        );
    }
  }

  IconData _icon(String name) {
    switch (name) {
      case 'people':
        return Icons.people_alt_outlined;
      case 'work':
        return Icons.work_outline;
      case 'calendar':
        return Icons.calendar_month_outlined;
      case 'gavel':
        return Icons.gavel_outlined;
      case 'payments':
        return Icons.payments_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'event_available':
        return Icons.event_available_outlined;
      case 'folder':
        return Icons.folder_copy_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'fingerprint':
        return Icons.fingerprint_outlined;
      case 'timer':
        return Icons.timer_outlined;
      case 'schedule':
        return Icons.schedule_outlined;
      case 'assignment_ind':
        return Icons.assignment_ind_outlined;
      case 'calendar_month':
        return Icons.calendar_month_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      default:
        return Icons.apps_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profile.role;
    final modules = AppRoles.modulesFor(role);

    return AppScaffold(
      title: 'لوحة الإدارة',
      floatingActionButton: AppRoles.canCreateEmployees(role)
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('إضافة موظف'),
            )
          : null,
      body: FutureBuilder<List<ProfileModel>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const AppLoadingState(label: 'جاري تحميل لوحة الإدارة');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل لوحة الإدارة',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final employees = snapshot.data ?? const <ProfileModel>[];
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildMetrics(context, employees),
                  const SizedBox(height: 18),
                  if (AppRoles.canViewReports(role)) ...[
                    _ReportsShortcut(
                      onTap: () => _open(
                        ReportsDashboardScreen(currentProfile: widget.profile),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  ..._buildSections(context, modules),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 26, child: Icon(_roleIcon(widget.profile.role))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.roleLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(_roleDescription(widget.profile.role)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, List<ProfileModel> employees) {
    final active = employees.where((employee) => employee.active).length;
    final management = employees
        .where((employee) => employee.isManagement)
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final cards = [
          _MetricData(
            'الموظفون',
            employees.length.toString(),
            Icons.groups_outlined,
          ),
          _MetricData(
            'النشطون',
            active.toString(),
            Icons.verified_user_outlined,
          ),
          _MetricData(
            'الإداريون',
            management.toString(),
            Icons.admin_panel_settings_outlined,
          ),
        ];
        if (compact) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _MetricCard(data: cards[i])),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (item) => SizedBox(width: 210, child: _MetricCard(data: item)),
              )
              .toList(),
        );
      },
    );
  }

  List<Widget> _buildSections(BuildContext context, List<AdminModule> modules) {
    final sections = <Widget>[];
    for (final category in AdminModuleCategory.values) {
      final items = modules
          .where((module) => module.category == category)
          .toList();
      if (items.isEmpty) continue;
      final meta = _categoryMeta(category);
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 22));
      sections.add(
        _AdminSection(
          title: meta.$1,
          subtitle: meta.$2,
          icon: meta.$3,
          modules: items,
          iconBuilder: _icon,
          onTap: _openModule,
        ),
      );
    }
    return sections;
  }

  (String, String, IconData) _categoryMeta(AdminModuleCategory category) {
    switch (category) {
      case AdminModuleCategory.people:
        return (
          'الموظفون والهيكل',
          'بيانات الموظفين والمسميات الوظيفية',
          Icons.groups_2_outlined,
        );
      case AdminModuleCategory.attendance:
        return (
          'الدوام والورديات',
          'السياسات والورديات والجداول والبصمة والإضافي',
          Icons.schedule_outlined,
        );
      case AdminModuleCategory.approvals:
        return (
          'الطلبات والاعتمادات',
          'الإجازات والجزاءات وما يحتاج قرارًا إداريًا',
          Icons.fact_check_outlined,
        );
      case AdminModuleCategory.finance:
        return (
          'المالية',
          'الرواتب والسلف والصناديق والحركات المالية',
          Icons.account_balance_outlined,
        );
      case AdminModuleCategory.system:
        return (
          'إدارة النظام',
          'المستندات والصلاحيات والعمليات الإدارية',
          Icons.settings_suggest_outlined,
        );
    }
  }

  IconData _roleIcon(String role) {
    if (AppRoles.isHr(role)) return Icons.badge_outlined;
    if (AppRoles.isGeneralManager(role)) return Icons.business_center_outlined;
    if (AppRoles.isFinancialManager(role))
      return Icons.account_balance_outlined;
    return Icons.person_outline;
  }

  String _roleDescription(String role) {
    switch (role) {
      case AppRoles.hrAdmin:
        return 'إدارة الموظفين والدوام والطلبات والمالية والمستندات من أقسام واضحة حسب سير العمل.';
      case AppRoles.generalManager:
        return 'متابعة الموظفين والدوام والاعتمادات، مع الوصول إلى التقارير المسموح بها.';
      case AppRoles.financialManager:
        return 'إدارة الرواتب والسلف والصناديق، مع دليل الموظفين والتقارير المالية.';
      default:
        return 'لا توجد صلاحيات إدارية لهذا الحساب.';
    }
  }
}

class _AdminSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<AdminModule> modules;
  final IconData Function(String) iconBuilder;
  final ValueChanged<AdminModule> onTap;

  const _AdminSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.modules,
    required this.iconBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            const gap = 10.0;
            final itemWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: modules
                  .map(
                    (module) => SizedBox(
                      width: itemWidth,
                      child: AppCard(
                        onTap: () => onTap(module),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Icon(
                                iconBuilder(module.iconName),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    module.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    module.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_left),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ReportsShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const _ReportsShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.analytics_outlined)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مركز التقارير',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                const Text('التقارير الإدارية والمالية مع PDF والطباعة.'),
              ],
            ),
          ),
          const Icon(Icons.chevron_left),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;

  const _MetricData(this.label, this.value, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 20),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
