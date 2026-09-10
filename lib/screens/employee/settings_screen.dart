import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final localAuth = LocalAuthentication();
    var available = false;
    try {
      available = await localAuth.isDeviceSupported() &&
          await localAuth.canCheckBiometrics;
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      _biometricsAvailable = available;
      _loading = false;
    });
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (enabled && !_biometricsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المصادقة بالبصمة غير متاحة على هذا الجهاز.')),
      );
      return;
    }

    if (enabled) {
      try {
        final localAuth = LocalAuthentication();
        final authenticated = await localAuth.authenticate(
          localizedReason: 'تحقق من هويتك لتفعيل حماية التطبيق بالبصمة',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (!authenticated) return;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر التحقق من البصمة.')),
          );
        }
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', enabled);
    if (!mounted) return;
    setState(() => _biometricsEnabled = enabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'تم تفعيل حماية التطبيق بالبصمة.' : 'تم تعطيل حماية التطبيق بالبصمة.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإعدادات',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'الأمان والدخول',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    AppCard(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('حماية التطبيق بالبصمة'),
                        subtitle: Text(
                          _biometricsAvailable
                              ? 'سيطلب التطبيق بصمتك عند فتح جلسة مسجلة مسبقًا.'
                              : 'البصمة غير متاحة أو غير مهيأة على هذا الجهاز.',
                        ),
                        value: _biometricsEnabled,
                        onChanged: _biometricsAvailable ? _toggleBiometrics : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'حول النظام',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.factory_outlined),
                        title: Text('نظام إدارة موظفي المصنع'),
                        subtitle: Text('إدارة الموظفين والدوام والرواتب والسلف والتقارير.'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
