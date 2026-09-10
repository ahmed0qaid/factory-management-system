import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';
import 'add_penalty_screen.dart';
import 'create_employee_screen.dart';
import 'manage_advances_screen.dart';
import 'manage_funds_screen.dart';
import 'manage_leaves_screen.dart';
import 'attendance_policy_screen.dart';
import 'shifts_screen.dart';
import 'employee_shift_assignments_screen.dart';
import 'monthly_work_schedule_screen.dart';
import 'import_biometric_screen.dart';
import 'manage_overtime_screen.dart';
import 'manage_employees_screen.dart';
import 'manage_payroll_screen.dart';
import 'employee_documents_screen.dart';
import 'job_titles_screen.dart';

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

  void _openModule(AdminModule module) {
    final role = widget.profile.role;
    final canEdit = switch (module.title) {
      'الموظفون' => AppRoles.canEditEmployees(role),
      'المسميات الوظيفية' => AppRoles.isHr(role),
      'سياسات الدوام' => AppRoles.canManageAttendance(role),
      'إدارة الورديات' => AppRoles.canManageAttendance(role),
      'تعيين دوام الموظفين' => AppRoles.canManageAttendance(role),
      'توليد الجداول' => AppRoles.canManageAttendance(role),
      'استيراد البصمة' => AppRoles.canManageAttendance(role),
      'إدارة الوقت الإضافي' => AppRoles.canManageAttendance(role),
      'الحضور والدوام' => AppRoles.canManageAttendance(role),
      'الجزاءات' => AppRoles.canManagePenalties(role),
      'الرواتب' => AppRoles.canManagePayroll(role),
      'السلف' => AppRoles.canManageAdvances(role),
      'الصندوق' => AppRoles.canManageFunds(role),
      'الإجازات والاستئذان' => AppRoles.canManageLeaveRequests(role),
      'مستندات الموظفين' => AppRoles.canManageDocuments(role),
      'الصلاحيات وسجل النظام' => AppRoles.canViewAuditLogs(role),
      _ => false,
    };

    if (module.title == 'الموظفون' && canEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManageEmployeesScreen(currentProfile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'المسميات الوظيفية' && canEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JobTitlesScreen(currentProfile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'الرواتب' && canEdit) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ManagePayrollScreen()));
      return;
    }

    if (module.title == 'مستندات الموظفين' && canEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EmployeeDocumentsScreen()),
      );
      return;
    }

    if (module.title == 'سياسات الدوام' && canEdit) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AttendancePolicyScreen()));
      return;
    }

    if (module.title == 'إدارة الورديات' && canEdit) {
      debugPrint('OPEN_SHIFTS_SCREEN');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShiftsScreen(profile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'تعيين دوام الموظفين' && canEdit) {
      debugPrint('OPEN_EMPLOYEE_SHIFT_ASSIGNMENTS_SCREEN');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeShiftAssignmentsScreen(profile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'توليد الجداول' && canEdit) {
      debugPrint('OPEN_MONTHLY_WORK_SCHEDULE_SCREEN');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MonthlyWorkScheduleScreen(profile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'استيراد البصمة' && canEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ImportBiometricScreen(companyId: widget.profile.companyId),
        ),
      );
      return;
    }

    if (module.title == 'إدارة الوقت الإضافي' && canEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ManageOvertimeScreen(companyId: widget.profile.companyId),
        ),
      );
      return;
    }

    if (module.title == 'الإجازات والاستئذان') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ManageLeavesScreen()));
      return;
    }

    if (module.title == 'السلف') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManageAdvancesScreen(currentProfile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'الصندوق' && canEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManageFundsScreen(currentProfile: widget.profile),
        ),
      );
      return;
    }

    if (module.title == 'الجزاءات' && canEdit) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AddPenaltyScreen()));
      return;
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

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AppScaffold(
      title: 'الموارد البشرية',
      floatingActionButton: AppRoles.canCreateEmployees(role)
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة موظف'),
            )
          : null,
      body: FutureBuilder<List<ProfileModel>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError)
            return const AppLoadingState(label: 'جاري تحميل اللوحة');
          if (snapshot.hasError)
            return AppErrorState(
              title: 'خطأ',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          final employees = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة الإدارة — ${widget.profile.roleLabel}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_roleDescription(role)),
                  ],
                ),
              ),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric('الموظفون', employees.length.toString()),
                    _metric(
                      'النشطون',
                      employees.where((e) => e.active).length.toString(),
                    ),
                    _metric(
                      'الإداريون',
                      employees.where((e) => e.isManagement).length.toString(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'صلاحياتك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 850
                        ? 3
                        : constraints.maxWidth > 560
                        ? 2
                        : 1;
                    return Wrap(
                      children: modules.map((module) {
                        return SizedBox(
                          width: constraints.maxWidth / crossAxisCount,
                          child: AppCard(
                            onTap: () => _openModule(module),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  child: Icon(_icon(module.iconName)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        module.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        module.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isRtl
                                      ? Icons.chevron_left
                                      : Icons.chevron_right,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'آخر الموظفين',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...employees
                  .take(10)
                  .map(
                    (e) => AppListItem(
                      leading: CircleAvatar(
                        child: Text(
                          e.fullName.isNotEmpty ? e.fullName[0] : 'م',
                        ),
                      ),
                      title: Text(e.fullName),
                      subtitle: Text(
                        '${e.employeeNumber} — ${e.jobTitleName ?? 'بدون مسمى'}',
                      ),
                      trailing: AppStatusPill(
                        label: e.roleLabel,
                        color: AppRoles.isHr(e.role) ? AppColors.primary : AppColors.secondary,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  String _roleDescription(String role) {
    switch (role) {
      case AppRoles.hrAdmin:
        return 'لديك الإمكانيات المطلقة: الموظفون، الدوام، الرواتب، السلف، الجزاءات، الإجازات، المستندات، الصلاحيات وسجل النظام.';
      case AppRoles.generalManager:
        return 'لديك صلاحية إدارية عليا للعرض والاعتماد في الدوام والجزاءات والإجازات، مع الاطلاع على التقارير.';
      case AppRoles.financialManager:
        return 'لديك صلاحية مالية لإدارة الرواتب والسلف والأقساط والتقارير المالية، مع عرض بيانات الموظفين اللازمة.';
      default:
        return 'لا توجد صلاحيات إدارية لهذا الحساب.';
    }
  }

  Widget _metric(String title, String value) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 26, ),
      ),
      Text(title),
    ],
  );
}


