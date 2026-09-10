import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/profile_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileModel profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricsStatus();
  }

  Future<void> _loadBiometricsStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', value);
    if (mounted) {
      setState(() {
        _biometricsEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'تم تفعيل حماية البصمة' : 'تم تعطيل حماية البصمة',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                child: Text(
                  widget.profile.fullName.isNotEmpty
                      ? widget.profile.fullName[0]
                      : 'م',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.profile.fullName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(),
              ),
              const SizedBox(height: 4),
              Text(widget.profile.jobTitleName ?? 'بدون مسمى وظيفي'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              _line('رقم الموظف', widget.profile.employeeNumber),
              const Divider(),
              _line('القسم', widget.profile.departmentName ?? '-'),
              const Divider(),
              _line('المسمى الوظيفي', widget.profile.jobTitleName ?? '-'),
              const Divider(),
              _line('الدور في النظام', widget.profile.roleLabel),
              const Divider(),
              _line('الهاتف', widget.profile.phone ?? '-'),
              const Divider(),
              _line(
                'الراتب الأساسي',
                Formatters.money(widget.profile.baseSalary),
              ),
              const Divider(),
              _line(
                'المكافأة الشهرية',
                Formatters.money(widget.profile.monthlyBonus),
              ),
              const Divider(),
              _line(
                'المستحق الشهري',
                Formatters.money(widget.profile.monthlyEntitlement),
              ),
              const Divider(),
              _line('حالة الحساب', widget.profile.active ? 'نشط' : 'موقوف'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إعدادات الأمان',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('تفعيل حماية التطبيق بالبصمة'),
                subtitle: const Text('سيطلب التطبيق البصمة عند الدخول'),
                value: _biometricsEnabled,
                onChanged: _toggleBiometrics,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}


