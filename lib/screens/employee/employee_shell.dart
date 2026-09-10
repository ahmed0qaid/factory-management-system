import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/force_password_change_screen.dart';
import '../auth/login_screen.dart';
import '../reports/employee_full_report_screen.dart';
import '../reports/report_list_screen.dart';
import '../reports/reports_dashboard_screen.dart';
import 'advances_screen.dart';
import 'attendance_screen.dart';
import 'employee_home_screen.dart';
import 'payroll_screen.dart';
import 'penalties_screen.dart';
import 'profile_screen.dart';

class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key});

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  final _service = EmployeeService();
  final _auth = AuthService();
  int _index = 0;
  late Future<ProfileModel> _profileFuture;
  bool _isAuthenticated = false;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAndLoad();
  }

  Future<void> _checkBiometricsAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometrics_enabled') ?? false;

    if (enabled) {
      final localAuth = LocalAuthentication();
      try {
        final authenticated = await localAuth.authenticate(
          localizedReason: 'الرجاء التحقق من هويتك للمتابعة',
        );
        if (authenticated) {
          if (mounted) setState(() => _isAuthenticated = true);
        } else {
          // If failed or canceled, stay locked or exit.
          return;
        }
      } catch (e) {
        // Fallback if error
        if (mounted) setState(() => _isAuthenticated = true);
      }
    } else {
      if (mounted) setState(() => _isAuthenticated = true);
    }

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _profileFuture = _service.getMyProfile();
      });
    }
  }

  void _reloadProfile() {
    setState(() {
      _index = 0;
      _profileFuture = _service.getMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return const AppScaffold(
        title: '',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAuthenticated) {
      return AppScaffold(
        title: 'قفل التطبيق',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'التطبيق مقفل',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AppLoadingButton(
                onPressed: _checkBiometricsAndLoad,
                icon: Icons.fingerprint,
                text: 'افتح باستخدام البصمة',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                child: const Text('تسجيل خروج'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<ProfileModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppScaffold(
            title: 'تحميل',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AppScaffold(
            title: 'خطأ',
            body: Center(child: Text('خطأ في تحميل الحساب: ${snapshot.error}')),
          );
        }
        final profile = snapshot.data!;

        if (profile.mustChangePassword) {
          return ForcePasswordChangeScreen(onPasswordChanged: _reloadProfile);
        }

        final pages = [
          EmployeeHomeScreen(profile: profile),
          const AttendanceScreen(),
          const PenaltiesScreen(),
          const PayrollScreen(),
          const AdvancesScreen(),
          ProfileScreen(profile: profile),
          if (profile.isManagement) AdminDashboardScreen(profile: profile),
        ];
        final destinations = <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'الدوام',
          ),
          const NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel),
            label: 'الجزاءات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'الراتب',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'السلف',
          ),
          const NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'بياناتي',
          ),
          if (profile.isManagement)
            NavigationDestination(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: const Icon(Icons.admin_panel_settings),
              label: profile.roleLabel,
            ),
        ];

        if (_index >= pages.length) _index = 0;

        return AppScaffold(
          title: destinations[_index].label,
          drawer: _buildDrawer(profile, destinations),
          actions: [
            IconButton(
              tooltip: 'تسجيل خروج',
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _auth.signOut();
                if (!mounted) return;
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          body: pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: destinations,
          ),
        );
      },
    );
  }

  Widget _buildDrawer(
    ProfileModel profile,
    List<NavigationDestination> destinations,
  ) {
    void selectDestination(int index) {
      Navigator.of(context).pop();
      setState(() => _index = index);
    }

    void openReportsDashboard() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportsDashboardScreen(currentProfile: profile),
        ),
      );
    }

    void openEmployeeFullReport() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeFullReportScreen(currentProfile: profile),
        ),
      );
    }

    void openReportList(ReportKind kind) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportListScreen(currentProfile: profile, kind: kind),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: profile.photoPath == null
                        ? Text(
                            profile.fullName.isNotEmpty
                                ? profile.fullName[0]
                                : 'م',
                          )
                        : const Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HR Employee System',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile.roleLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    ListTile(
                      leading: _index == i
                          ? destinations[i].selectedIcon ?? destinations[i].icon
                          : destinations[i].icon,
                      title: Text(destinations[i].label),
                      selected: _index == i,
                      onTap: () => selectDestination(i),
                    ),
                  if (AppRoles.canViewReports(profile.role)) ...[
                    const Divider(),
                    ExpansionTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: const Text('التقارير'),
                      childrenPadding: const EdgeInsetsDirectional.only(
                        start: 16,
                      ),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dashboard_outlined),
                          title: const Text('لوحة التقارير'),
                          onTap: openReportsDashboard,
                        ),
                        if (AppRoles.canViewEmployeeFullReport(profile.role))
                          ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: const Text('التقرير الشامل للموظف'),
                            onTap: openEmployeeFullReport,
                          ),
                        ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: const Text('تقارير الحضور والانصراف'),
                          onTap: AppRoles.canViewAttendanceReports(profile.role)
                              ? () => openReportList(ReportKind.attendance)
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: const Text('تقارير الرواتب'),
                          onTap: AppRoles.canViewPayrollReports(profile.role)
                              ? () => openReportList(ReportKind.payroll)
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          title: const Text('تقارير السلف'),
                          onTap: AppRoles.canViewAdvancesReports(profile.role)
                              ? () => openReportList(ReportKind.advances)
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.gavel_outlined),
                          title: const Text('تقارير الجزاءات'),
                          onTap: AppRoles.canViewPenaltiesReports(profile.role)
                              ? () => openReportList(ReportKind.penalties)
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.event_available_outlined),
                          title: const Text('تقارير الإجازات'),
                          onTap: AppRoles.canViewLeavesReports(profile.role)
                              ? () => openReportList(ReportKind.leaves)
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.timer_outlined),
                          title: const Text('تقارير العمل الإضافي'),
                          onTap: AppRoles.canViewOvertimeReports(profile.role)
                              ? () => openReportList(ReportKind.overtime)
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.folder_copy_outlined),
                          title: const Text('تقارير مستندات الموظفين'),
                          onTap: AppRoles.canViewDocumentReports(profile.role)
                              ? () => openReportList(ReportKind.documents)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('الإعدادات'),
              onTap: () => selectDestination(destinations.length >= 6 ? 5 : 0),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () async {
                final navigator = Navigator.of(context);
                await _auth.signOut();
                if (!mounted) return;
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
