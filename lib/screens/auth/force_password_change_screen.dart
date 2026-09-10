import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const ForcePasswordChangeScreen({
    super.key,
    required this.onPasswordChanged,
  });

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

  @override
  void dispose() {
    _oldPassword.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await _auth.changeTemporaryPassword(
        oldPassword: _oldPassword.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح.')),
      );
      widget.onPasswordChanged();
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
      title: '',
      showAppBar: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AppCard(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.lock_reset,
                            size: 56,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'تعيين كلمة مرور جديدة',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'هذه أول مرة تسجل فيها الدخول. أكمل هذه الخطوة مرة واحدة قبل استخدام النظام.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 28),
                          AppFormField(
                            controller: _oldPassword,
                            isPassword: true,
                            labelText: 'كلمة المرور المؤقتة',
                            prefixIcon: Icons.lock_outline,
                            textInputAction: TextInputAction.next,
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
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
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
                            controller: _confirm,
                            isPassword: true,
                            labelText: 'تأكيد كلمة المرور',
                            prefixIcon: Icons.check_circle_outline,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_loading) _save();
                            },
                            validator: (value) => value != _password.text
                                ? 'كلمتا المرور غير متطابقتين'
                                : null,
                          ),
                          const SizedBox(height: 28),
                          AppLoadingButton(
                            text: 'حفظ ومتابعة',
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
