import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/employee_tab_navigation.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/force_password_change_screen.dart';
import '../auth/login_screen.dart';
import '../reports/reports_dashboard_screen.dart';
import 'advances_screen.dart';
import 'attendance_screen.dart';
import 'employee_home_screen.dart';
import 'leave_requests_screen.dart';
import 'notifications_screen.dart';
import 'payroll_screen.dart';
import 'penalties_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

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
  String? _authenticationMessage;

  @override
  void initState() {
    super.initState();
    EmployeeTabNavigation.requestedIndex.addListener(_handleTabRequest);
    _checkBiometricsAndLoad();
  }

  @override
  void dispose() {
    EmployeeTabNavigation.requestedIndex.removeListener(_handleTabRequest);
    super.dispose();
  }

  void _handleTabRequest() {
    final requested = EmployeeTabNavigation.requestedIndex.value;
    if (requested == null || requested < 0 || requested > 4) return;
    if (mounted) setState(() => _index = requested);
    EmployeeTabNavigation.clear();
  }

  Future<void> _checkBiometricsAndLoad() async {
    if (mounted) {
      setState(() {
        _isAuthenticating = true;
        _authenticationMessage = null;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometrics_enabled') ?? false;

    if (enabled) {
      final localAuth = LocalAuthentication();
      try {
        final supported = await localAuth.isDeviceSupported();
        final canCheck = await localAuth.canCheckBiometrics;
        if (!supported || !canCheck) {
          if (!mounted) return;
          setState(() {
            _isAuthenticated = false;
            _isAuthenticating = false;
            _authenticationMessage =
                'تعذر استخدام البصمة على هذا الجهاز. يمكنك إعادة المحاولة أو تسجيل الخروج.';
          });
          return;
        }

        final authenticated = await localAuth.authenticate(
          localizedReason: 'تحقق من هويتك لفتح نظام إدارة موظفي المصنع',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (!authenticated) {
          if (!mounted) return;
          setState(() {
            _isAuthenticated = false;
            _isAuthenticating = false;
            _authenticationMessage = 'لم يتم التحقق من البصمة.';
          });
          return;
        }
      } on LocalAuthException catch (error) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = false;
          _isAuthenticating = false;
          _authenticationMessage = switch (error.code) {
            LocalAuthExceptionCode.userCanceled => 'تم إلغاء التحقق من البصمة.',
            LocalAuthExceptionCode.temporaryLockout =>
              'تم إيقاف البصمة مؤقتًا بسبب محاولات متكررة. حاول لاحقًا.',
            LocalAuthExceptionCode.biometricLockout =>
              'البصمة مقفلة على الجهاز. افتح الجهاز بالطريقة الأساسية ثم أعد المحاولة.',
            _ => 'تعذر التحقق من البصمة. لم يتم تجاوز حماية التطبيق.',
          };
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = false;
          _isAuthenticating = false;
          _authenticationMessage =
              'حدث خطأ أثناء التحقق من البصمة. لم يتم تجاوز حماية التطبيق.';
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isAuthenticated = true;
      _isAuthenticating = false;
      _authenticationMessage = null;
      _profileFuture = _service.getMyProfile();
    });
  }

  void _reloadProfile() {
    setState(() {
      _index = 0;
      _profileFuture = _service.getMyProfile();
    });
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await _auth.signOut();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return const AppScaffold(
        title: '',
        showAppBar: false,
        body: AppLoadingState(label: 'جاري التحقق من الحساب'),
      );
    }

    if (!_isAuthenticated) {
      return AppScaffold(
        title: 'قفل التطبيق',
        body: _buildLockedState(context),
      );
    }

    return FutureBuilder<ProfileModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppScaffold(
            title: 'تحميل الحساب',
            body: AppLoadingState(label: 'جاري تحميل بيانات الحساب'),
          );
        }
        if (snapshot.hasError) {
          return AppScaffold(
            title: 'تعذر تحميل الحساب',
            body: AppErrorState(
              title: 'تعذر تحميل بيانات الحساب',
              message: 'تحقق من الاتصال ثم أعد المحاولة.',
              onRetry: _reloadProfile,
            ),
          );
        }

        final profile = snapshot.data!;
        if (profile.mustChangePassword) {
          return ForcePasswordChangeScreen(onPasswordChanged: _reloadProfile);
        }

        final pages = <Widget>[
          EmployeeHomeScreen(profile: profile),
          const AttendanceScreen(),
          const PayrollScreen(),
          AdvancesScreen(isActive: _index == 3),
          ProfileScreen(profile: profile),
        ];

        const destinations = <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'الدوام',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'الراتب',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'السلف',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ];

        if (_index >= pages.length) _index = 0;

        return AppScaffold(
          title: destinations[_index].label,
          actions: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () => _openPage(const NotificationsScreen()),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          ],
          drawer: _buildDrawer(profile),
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: destinations,
          ),
        );
      },
    );
  }

  Widget _buildLockedState(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 32,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'التطبيق مقفل',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _authenticationMessage ??
                    'استخدم البصمة المفعلة على جهازك للمتابعة.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppLoadingButton(
                  onPressed: _checkBiometricsAndLoad,
                  icon: Icons.fingerprint,
                  text: 'إعادة محاولة البصمة',
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(ProfileModel profile) {
    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    void open(Widget page) => _openPage(page);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Text(
                      profile.fullName.isNotEmpty ? profile.fullName[0] : 'م',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نظام إدارة موظفي المصنع',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile.roleLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (profile.isManagement)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('لوحة الإدارة'),
                      subtitle: const Text('إدارة الموظفين والدوام والمالية'),
                      onTap: () => closeThen(
                        () => open(AdminDashboardScreen(profile: profile)),
                      ),
                    ),
                  if (AppRoles.canViewReports(profile.role))
                    ListTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: const Text('التقارير'),
                      subtitle: const Text('مركز التقارير والتصدير والطباعة'),
                      onTap: () => closeThen(
                        () => open(
                          ReportsDashboardScreen(currentProfile: profile),
                        ),
                      ),
                    ),
                  if (profile.isManagement) const Divider(),
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('الإجازات والاستئذان'),
                    onTap: () => closeThen(
                      () => open(const LeaveRequestsScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('الجزاءات'),
                    onTap: () => closeThen(
                      () => open(const PenaltiesScreen(showAppBar: true)),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('الإعدادات'),
                    subtitle: const Text('الأمان والبصمة وإعدادات التطبيق'),
                    onTap: () => closeThen(
                      () => open(const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                'تسجيل الخروج',
                style: TextStyle(color: scheme.error),
              ),
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}
