import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _auth.changePassword(
        oldPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير كلمة المرور: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تغيير كلمة المرور',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppFormField(
                        controller: _currentPassword,
                        isPassword: true,
                        labelText: 'كلمة المرور الحالية',
                        prefixIcon: Icons.lock_outline,
                        textInputAction: TextInputAction.next,
                        validator: (value) => value == null || value.length < 8
                            ? 'أدخل كلمة المرور الحالية'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _newPassword,
                        isPassword: true,
                        labelText: 'كلمة المرور الجديدة',
                        prefixIcon: Icons.lock_reset,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
                          }
                          if (value == _currentPassword.text) {
                            return 'اختر كلمة مرور مختلفة عن الحالية';
                          }
                          if (value == '12345678' ||
                              value.toLowerCase() == 'password') {
                            return 'اختر كلمة مرور أقوى';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _confirmPassword,
                        isPassword: true,
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        prefixIcon: Icons.check_circle_outline,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_loading) _save();
                        },
                        validator: (value) => value != _newPassword.text
                            ? 'كلمتا المرور غير متطابقتين'
                            : null,
                      ),
                      const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}
