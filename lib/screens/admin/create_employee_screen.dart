import 'package:flutter/material.dart';

import '../../models/job_title_model.dart';
import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/job_title_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class CreateEmployeeScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const CreateEmployeeScreen({super.key, required this.currentProfile});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  static final _phonePattern = RegExp(r'^\+[0-9]{8,15}$');
  final _formKey = GlobalKey<FormState>();
  final _service = AdminService();
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _salary = TextEditingController();
  final _monthlyBonus = TextEditingController();
  final _biometric = TextEditingController();
  bool _loading = false;
  String _role = AppRoles.employee;

  final _jobTitleService = JobTitleService();
  List<JobTitleModel> _jobTitles = [];
  final List<JobTitleModel> _selectedJobTitles = [];
  bool _loadingTitles = true;

  @override
  void initState() {
    super.initState();
    _loadJobTitles();
  }

  Future<void> _loadJobTitles() async {
    try {
      final titles = await _jobTitleService.getJobTitles(
        companyId: widget.currentProfile.companyId,
        activeOnly: true,
      );
      if (mounted) {
        setState(() {
          _jobTitles = titles;
          _loadingTitles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTitles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل المسميات الوظيفية: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!AppRoles.canCreateEmployees(widget.currentProfile.role)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليست لديك صلاحية إنشاء حسابات')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _service.createEmployee(
        employeeNumber: _number.text.trim(),
        fullName: _name.text.trim(),
        temporaryPassword: _password.text,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        baseSalary: num.tryParse(_salary.text.trim()) ?? 0,
        monthlyBonus: num.tryParse(_monthlyBonus.text.trim()) ?? 0,
        biometricEmployeeId: _biometric.text.trim().isEmpty
            ? null
            : _biometric.text.trim(),
        role: _role,
        jobTitleId: _selectedJobTitles.map((t) => t.id).join(','),
        jobTitleName: _selectedJobTitles.map((t) => t.name).join(','),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء الحساب وسيُطلب منه تغيير كلمة المرور عند أول دخول',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!AppRoles.canCreateEmployees(widget.currentProfile.role)) {
      return const AppScaffold(
        title: 'إضافة موظف',
        body: AppEmptyState(
          title: 'لا توجد صلاحية',
          message: 'هذه الشاشة متاحة للموارد البشرية فقط.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return AppScaffold(
      title: 'إضافة موظف / مستخدم',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppCard(
              elevated: true,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'بيانات الدخول',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _number,
                      labelText: 'رقم الموظف / اسم الدخول',
                      prefixIcon: Icons.badge_outlined,
                      validator: _required,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _password,
                      labelText: 'كلمة مرور مؤقتة',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'بيانات الموظف',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _name,
                      labelText: 'اسم الموظف',
                      prefixIcon: Icons.person_outline,
                      validator: _required,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      labelText: 'الهاتف',
                      prefixIcon: Icons.phone_outlined,
                      validator: _phoneValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _salary,
                      keyboardType: TextInputType.number,
                      labelText: 'الراتب الأساسي',
                      prefixIcon: Icons.attach_money_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _monthlyBonus,
                      keyboardType: TextInputType.number,
                      labelText: 'المكافأة الشهرية',
                      prefixIcon: Icons.money_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_loadingTitles)
                      const SizedBox(
                        height: 96,
                        child: AppLoadingState(
                          label: 'جاري تحميل المسميات الوظيفية',
                          fallbackHeight: 96,
                        ),
                      )
                    else if (_jobTitles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.error.withValues(alpha: .28),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'لا توجد مسميات وظيفية مفعلة. يرجى إضافتها أولاً من إدارة المسميات.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      FormField<List<JobTitleModel>>(
                        initialValue: _selectedJobTitles,
                        validator: (val) => _selectedJobTitles.isEmpty
                            ? 'يرجى اختيار المسمى الوظيفي'
                            : null,
                        builder: (state) {
                          return InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'المسمى الوظيفي',
                              hintText: 'اختر مسمى وظيفي واحد أو أكثر',
                              errorText: state.errorText,
                            ),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: _jobTitles.map((title) {
                                final isSelected =
                                    _selectedJobTitles.contains(title);
                                return FilterChip(
                                  label: Text(title.name),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedJobTitles.add(title);
                                      } else {
                                        _selectedJobTitles.remove(title);
                                      }
                                      state.didChange(_selectedJobTitles);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: AppSpacing.md),
                    AppFormField(
                      controller: _biometric,
                      labelText: 'رقم البصمة (اختياري)',
                      prefixIcon: Icons.fingerprint_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'المستحق الشهري = الراتب الأساسي + المكافأة الشهرية',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppDropdownField<String>(
                      labelText: 'الدور / الصلاحية',
                      value: _role,
                      items: AppRoles.assignableRoles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(AppRoles.label(role)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _role = value ?? AppRoles.employee),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'بعد أول تسجيل دخول، سيجبر النظام المستخدم على تغيير كلمة المرور المؤقتة. يجب أن تكون كلمة المرور المؤقتة 8 أحرف على الأقل.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppLoadingButton(
                      onPressed: _save,
                      icon: Icons.save_outlined,
                      text: 'حفظ',
                      isLoading: _loading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  String? _phoneValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!_phonePattern.hasMatch(value)) {
      return 'أدخل رقم الهاتف بصيغة دولية مثل +967770000000';
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'كلمة المرور المؤقتة مطلوبة';
    if (v.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    return null;
  }
}
