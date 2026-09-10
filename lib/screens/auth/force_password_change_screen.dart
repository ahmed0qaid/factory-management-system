import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const ForcePasswordChangeScreen({super.key, required this.onPasswordChanged});

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassword = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.changeTemporaryPassword(
        oldPassword: _oldPassword.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
      );
      widget.onPasswordChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تغيير كلمة المرور: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '', // No title needed
      centerTitle: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AppCard(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock_reset, size: 56, color: AppColors.primary),
                          const SizedBox(height: 16),
                          const Text(
                            'تغيير كلمة المرور',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'هذه أول مرة تسجل فيها الدخول. يجب تعيين كلمة مرور جديدة قبل استخدام النظام.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 32),
                          AppFormField(
                            controller: _oldPassword,
                            isPassword: true,
                            labelText: 'كلمة المرور المؤقتة الحالية',
                            prefixIcon: Icons.lock_outline,
                            validator: (value) =>
                                value == null || value.length < 8
                                ? 'أدخل كلمة المرور المؤقتة'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AppFormField(
                            controller: _password,
                            isPassword: true,
                            labelText: 'كلمة المرور الجديدة',
                            prefixIcon: Icons.lock_reset,
                            validator: (value) {
                              if (value == null || value.length < 8) return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
                              if (value == '12345678' || value.toLowerCase() == 'password') return 'اختر كلمة مرور أقوى';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppFormField(
                            controller: _confirm,
                            isPassword: true,
                            labelText: 'تأكيد كلمة المرور',
                            prefixIcon: Icons.check_circle_outline,
                            validator: (value) => value != _password.text
                                ? 'كلمتا المرور غير متطابقتين'
                                : null,
                          ),
                          const SizedBox(height: 32),
                          AppLoadingButton(
                            text: 'حفظ كلمة المرور',
                            icon: Icons.check,
                            isLoading: _loading,
                            onPressed: _save,
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


