import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_spacing.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppScaffold(
      title: '',
      showAppBar: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.xl,
              bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.xl * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AppCard(
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_reset,
                                size: 32,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'تعيين كلمة مرور جديدة',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'هذه أول مرة تسجل فيها الدخول. أكمل هذه الخطوة مرة واحدة قبل استخدام النظام.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
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
                          const SizedBox(height: AppSpacing.md),
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
                          const SizedBox(height: AppSpacing.md),
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
                          const SizedBox(height: AppSpacing.xl),
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
