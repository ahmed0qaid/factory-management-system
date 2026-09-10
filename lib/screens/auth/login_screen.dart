import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../employee/employee_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeNumber = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signInWithEmployeeNumber(
        employeeNumber: _employeeNumber.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmployeeShell()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '', // No title needed for login
      centerTitle: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AppCard(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.shield_outlined, size: 64, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(
                            'تسجيل دخول الموظف',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          AppFormField(
                            controller: _employeeNumber,
                            labelText: 'رقم الموظف',
                            prefixIcon: Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'أدخل رقم الموظف'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AppFormField(
                            controller: _password,
                            isPassword: true,
                            labelText: 'كلمة المرور',
                            prefixIcon: Icons.lock_outline,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                              if (v.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          AppLoadingButton(
                            text: 'دخول',
                            icon: Icons.login,
                            isLoading: _loading,
                            onPressed: _login,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'لا يوجد إنشاء حساب للموظف. يتم إنشاء الحساب من الإدارة فقط.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


