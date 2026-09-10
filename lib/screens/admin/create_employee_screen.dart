import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/job_title_service.dart';
import '../../models/job_title_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppRoles.canCreateEmployees(widget.currentProfile.role)) {
      return const Scaffold(
        body: Center(child: Text('هذه الشاشة متاحة للموارد البشرية فقط')),
      );
    }

    return AppScaffold(
      title: 'إضافة موظف / مستخدم',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  Text(
                    'بيانات الدخول',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _number,
                    labelText: 'رقم الموظف / اسم الدخول',
                    prefixIcon: Icons.badge_outlined,
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _password,
                    labelText: 'كلمة مرور مؤقتة',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: _passwordValidator,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    'بيانات الموظف',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _name,
                    labelText: 'اسم الموظف',
                    prefixIcon: Icons.person_outline,
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    labelText: 'الهاتف',
                    prefixIcon: Icons.phone_outlined,
                    validator: _phoneValidator,
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _salary,
                    keyboardType: TextInputType.number,
                    labelText: 'الراتب الأساسي',
                    prefixIcon: Icons.attach_money_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _monthlyBonus,
                    keyboardType: TextInputType.number,
                    labelText: 'المكافأة الشهرية',
                    prefixIcon: Icons.money_outlined,
                  ),
                  const SizedBox(height: 16),
                  if (_loadingTitles)
                    const Center(child: CircularProgressIndicator())
                  else if (_jobTitles.isEmpty)
                    const Text(
                      'لا توجد مسميات وظيفية مفعلة. يرجى إضافتها أولاً من إدارة المسميات.',
                      style: TextStyle(color: AppColors.danger),
                    )
                  else
                    FormField<List<JobTitleModel>>(
                      initialValue: _selectedJobTitles,
                      validator: (val) => _selectedJobTitles.isEmpty ? 'يرجى اختيار المسمى الوظيفي' : null,
                      builder: (FormFieldState<List<JobTitleModel>> state) {
                        return InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'المسمى الوظيفي',
                            hintText: 'اختر مسمى وظيفي واحد أو أكثر',
                            errorText: state.errorText,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _jobTitles.map((title) {
                              final isSelected = _selectedJobTitles.contains(title);
                              return FilterChip(
                                label: Text(title.name),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(alpha: .2),
                                checkmarkColor: AppColors.primary,
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
                  const SizedBox(height: 16),
                  AppFormField(
                    controller: _biometric,
                    labelText: 'رقم البصمة (اختياري)',
                    prefixIcon: Icons.fingerprint_outlined,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'المستحق الشهري = الراتب الأساسي + المكافأة الشهرية',
                    style: TextStyle(color: AppColors.secondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: .3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ملاحظة: بعد أول تسجيل دخول، سيجبر النظام المستخدم على تغيير كلمة المرور المؤقتة. يجب أن تكون كلمة المرور المؤقتة 8 أحرف على الأقل.',
                            style: TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppLoadingButton(
                    onPressed: _save,
                    icon: Icons.save,
                    text: 'حفظ',
                    isLoading: _loading,
                  ),
                ],
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


