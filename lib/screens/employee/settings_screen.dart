import 'package:flutter/material.dart';

import '../../services/app_biometric_lock_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme_controller.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../auth/change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _biometricService = AppBiometricLockService();

  bool _loading = true;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _auth.getCurrentUser();
      final available = await _biometricService.isAvailable();
      final enabled = await _biometricService.isEnabledForUser(user.$id);
      if (!mounted) return;
      setState(() {
        _userId = user.$id;
        _biometricsEnabled = enabled;
        _biometricsAvailable = available;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل إعدادات الأمان: $error')),
      );
    }
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    final userId = _userId;
    if (userId == null) return;

    if (enabled && !_biometricsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('قفل الجهاز الآمن غير متاح أو غير مهيأ على هذا الجهاز.'),
        ),
      );
      return;
    }

    if (enabled) {
      final result = await _biometricService.authenticate(
        localizedReason:
            'تحقق من هويتك لتفعيل حماية التطبيق بالبصمة أو قفل الجهاز',
      );
      if (!result.authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'تعذر التحقق من الهوية.'),
          ),
        );
        return;
      }
    }

    await _biometricService.setEnabledForUser(userId, enabled);
    if (!mounted) return;
    setState(() => _biometricsEnabled = enabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'تم تفعيل حماية التطبيق لهذا الحساب.'
              : 'تم تعطيل حماية التطبيق لهذا الحساب.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإعدادات',
      body: _loading
          ? const AppLoadingState(label: 'جاري تحميل الإعدادات')
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle(context, 'المظهر'),
                    const SizedBox(height: 8),
                    AppCard(
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: AppThemeController.mode,
                        builder: (context, mode, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.palette_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'مظهر التطبيق',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'اختر المظهر المناسب أو اجعله يتبع إعداد الجهاز.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.brightness_auto_outlined),
                                    label: Text('النظام'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode_outlined),
                                    label: Text('فاتح'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode_outlined),
                                    label: Text('داكن'),
                                  ),
                                ],
                                selected: {mode},
                                showSelectedIcon: false,
                                onSelectionChanged: (selection) {
                                  AppThemeController.setMode(selection.first);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(context, 'الأمان والدخول'),
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.fingerprint),
                            title: const Text('حماية التطبيق بقفل الجهاز'),
                            subtitle: Text(
                              _biometricsAvailable
                                  ? 'يستخدم التطبيق البصمة أولًا، ويمكن للنظام عرض رمز أو كلمة مرور الجهاز كبديل عند الحاجة.'
                                  : 'قفل الجهاز الآمن غير متاح أو غير مهيأ على هذا الجهاز.',
                            ),
                            value: _biometricsEnabled,
                            onChanged: _biometricsAvailable
                                ? _toggleBiometrics
                                : null,
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.password_outlined),
                            title: const Text('تغيير كلمة المرور'),
                            subtitle: const Text(
                              'غيّر كلمة مرور حسابك الحالية من داخل التطبيق.',
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(context, 'حول النظام'),
                    const SizedBox(height: 8),
                    const AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.factory_outlined),
                        title: Text('نظام إدارة موظفي المصنع'),
                        subtitle: Text(
                          'إدارة الموظفين والدوام والرواتب والسلف والتقارير.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
