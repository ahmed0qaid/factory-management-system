import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/app_biometric_lock_service.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/employee_tab_navigation.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_floating_navigation_bar.dart';
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

enum _ShellWorkspace { management, personal }

class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key});

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  final _service = EmployeeService();
  final _auth = AuthService();
  final _biometricService = AppBiometricLockService();

  int _index = 0;
  late Future<ProfileModel> _profileFuture;
  bool _isAuthenticated = false;
  bool _isAuthenticating = true;
  bool _isSigningOut = false;
  bool _workspaceInitialized = false;
  _ShellWorkspace _workspace = _ShellWorkspace.personal;
  String? _authenticationMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    EmployeeTabNavigation.requestedIndex.addListener(_handleTabRequest);
    _initializeSession();
  }

  @override
  void dispose() {
    EmployeeTabNavigation.requestedIndex.removeListener(_handleTabRequest);
    super.dispose();
  }

  void _handleTabRequest() {
    final requested = EmployeeTabNavigation.requestedIndex.value;
    if (requested == null || requested < 0 || requested > 4) return;
    if (mounted) {
      setState(() {
        _workspace = _ShellWorkspace.personal;
        _index = requested;
      });
    }
    EmployeeTabNavigation.clear();
  }

  void _initializeWorkspace(ProfileModel profile) {
    if (_workspaceInitialized) return;
    _workspace = profile.isManagement
        ? _ShellWorkspace.management
        : _ShellWorkspace.personal;
    _workspaceInitialized = true;
  }

  Future<void> _initializeSession() async {
    if (mounted) {
      setState(() {
        _isAuthenticating = true;
        _isAuthenticated = false;
        _authenticationMessage = null;
      });
    }

    try {
      final user = await _auth.getCurrentUser();
      final profile = await _service.getMyProfile();
      _currentUserId = user.$id;
      _initializeWorkspace(profile);
      _profileFuture = Future.value(profile);

      // تغيير كلمة المرور المؤقتة شرط سابق على أي قفل محلي بالبصمة.
      if (profile.mustChangePassword) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
        });
        return;
      }

      final enabled = await _biometricService.isEnabledForUser(user.$id);
      if (enabled) {
        final result = await _biometricService.authenticate(
          localizedReason: 'تحقق من هويتك لفتح نظام إدارة موظفي المصنع',
        );
        if (!result.authenticated) {
          if (!mounted) return;
          setState(() {
            _isAuthenticated = false;
            _isAuthenticating = false;
            _authenticationMessage = result.message;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _isAuthenticated = true;
        _isAuthenticating = false;
        _authenticationMessage = null;
      });
    } catch (error) {
      _profileFuture = Future<ProfileModel>.error(error);
      if (!mounted) return;
      setState(() {
        _isAuthenticated = true;
        _isAuthenticating = false;
      });
    }
  }

  void _reloadProfile() {
    setState(() {
      _index = 0;
      _workspaceInitialized = false;
    });
    _initializeSession();
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSigningOut = true);
    try {
      await _auth.signOut();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الخروج: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _requestSignOut() async {
    if (_isSigningOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من الحساب الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _signOut();
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

        const destinations = <AppFloatingNavigationItem>[
          AppFloatingNavigationItem(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          AppFloatingNavigationItem(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'الدوام',
          ),
          AppFloatingNavigationItem(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'الراتب',
          ),
          AppFloatingNavigationItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'السلف',
          ),
          AppFloatingNavigationItem(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ];

        if (_index >= pages.length) _index = 0;

        final actions = <Widget>[
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => _openPage(const NotificationsScreen()),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ];

        if (profile.isManagement &&
            _workspace == _ShellWorkspace.management) {
          return AppScaffold(
            title: 'لوحة الإدارة',
            actions: actions,
            drawer: _buildDrawer(profile),
            body: AdminDashboardScreen(profile: profile, embedded: true),
          );
        }

        return AppScaffold(
          title: destinations[_index].label,
          actions: actions,
          drawer: _buildDrawer(profile),
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: AppFloatingNavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            items: destinations,
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
                    'استخدم البصمة المفعلة لهذا الحساب للمتابعة.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppLoadingButton(
                  onPressed: _initializeSession,
                  icon: Icons.fingerprint,
                  text: 'إعادة محاولة البصمة',
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isSigningOut ? null : _requestSignOut,
                icon: const Icon(Icons.logout),
                label: Text(_isSigningOut ? 'جاري تسجيل الخروج...' : 'تسجيل الخروج'),
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

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

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
                  if (profile.isManagement) sectionLabel('الإدارة'),
                  if (profile.isManagement)
                    ListTile(
                      selected: _workspace == _ShellWorkspace.management,
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('لوحة الإدارة'),
                      subtitle: const Text('إدارة الموظفين والدوام والمالية'),
                      onTap: () => closeThen(
                        () => setState(
                          () => _workspace = _ShellWorkspace.management,
                        ),
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
                  if (profile.isManagement) ...[
                    const Divider(),
                    sectionLabel('المساحة الشخصية'),
                    ListTile(
                      selected: _workspace == _ShellWorkspace.personal,
                      leading: const Icon(Icons.person_outline),
                      title: const Text('مساحتي الشخصية'),
                      subtitle: const Text('دوامي وراتبي وسلفي وحسابي'),
                      onTap: () => closeThen(
                        () => setState(() {
                          _workspace = _ShellWorkspace.personal;
                          _index = 0;
                        }),
                      ),
                    ),
                  ],
                  if (!profile.isManagement) sectionLabel('المساحة الشخصية'),
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('طلباتي وإجازاتي'),
                    onTap: () =>
                        closeThen(() => open(const LeaveRequestsScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('جزاءاتي'),
                    onTap: () => closeThen(
                      () => open(const PenaltiesScreen(showAppBar: true)),
                    ),
                  ),
                  const Divider(),
                  sectionLabel('التطبيق'),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('الإعدادات'),
                    subtitle: const Text('الأمان والبصمة وإعدادات التطبيق'),
                    onTap: () => closeThen(() => open(const SettingsScreen())),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: !_isSigningOut,
              leading: _isSigningOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.logout, color: scheme.error),
              title: Text(
                _isSigningOut ? 'جاري تسجيل الخروج...' : 'تسجيل الخروج',
                style: TextStyle(color: scheme.error),
              ),
              onTap: _isSigningOut
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _requestSignOut();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
