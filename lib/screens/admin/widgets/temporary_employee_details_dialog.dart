import 'package:flutter/material.dart';

import '../../../models/job_title_model.dart';
import '../../../models/temporary_employee_model.dart';
import '../../../services/admin_biometrics_service.dart';
import '../../../services/admin_service.dart';
import '../../../services/job_title_service.dart';
import '../../../widgets/common/app_confirm_dialog.dart';
import '../../../widgets/common/app_dropdown_field.dart';
import '../../../widgets/common/app_form_field.dart';
import '../../../widgets/common/app_loading_state.dart';
import '../../../widgets/common/app_status_pill.dart';

class TemporaryEmployeeDetailsDialog extends StatefulWidget {
  final TemporaryEmployeeModel employee;
  final VoidCallback onChanged;

  const TemporaryEmployeeDetailsDialog({
    super.key,
    required this.employee,
    required this.onChanged,
  });

  @override
  State<TemporaryEmployeeDetailsDialog> createState() =>
      _TemporaryEmployeeDetailsDialogState();
}

class _TemporaryEmployeeDetailsDialogState
    extends State<TemporaryEmployeeDetailsDialog> {
  static final _phonePattern = RegExp(r'^\+[0-9]{8,15}$');
  final _biometricsService = AdminBiometricsService();
  final _adminService = AdminService();
  final _jobTitleService = JobTitleService();
  List<JobTitleModel> _activeJobTitles = [];
  bool _isLoading = false;
  bool _isLoadingTitles = true;

  @override
  void initState() {
    super.initState();
    _loadJobTitles();
  }

  Future<void> _loadJobTitles() async {
    try {
      final titles = await _jobTitleService.getJobTitles(
        companyId: widget.employee.companyId,
        activeOnly: true,
      );
      if (mounted) {
        setState(() {
          _activeJobTitles = titles;
          _isLoadingTitles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTitles = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _reject() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'تأكيد الرفض',
      content: 'هل تريد رفض رقم البصمة هذا؟ لن يتم إنشاء موظف رسمي له.',
      confirmText: 'رفض',
      isDestructive: true,
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _biometricsService.rejectTemporaryEmployee(widget.employee.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveNew() async {
    final formKey = GlobalKey<FormState>();
    String empNum = '';
    final nameController = TextEditingController(
      text: widget.employee.employeeNameFromDevice?.trim() ?? '',
    );
    String name = '';
    String pwd = '';
    String phone = '';
    String departmentName = '';
    JobTitleModel? selectedJobTitle;
    num? baseSalary;
    num? bonus;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            return AlertDialog(
              title: const Text('اعتماد كموظف رسمي جديد'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppFormField(
                          labelText: 'الرقم الوظيفي *',
                          prefixIcon: Icons.badge_outlined,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          onSaved: (v) => empNum = v!,
                        ),
                        const SizedBox(height: 12),
                        AppFormField(
                          controller: nameController,
                          labelText: 'الاسم الكامل *',
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          onSaved: (v) => name = v!,
                        ),
                        const SizedBox(height: 12),
                        AppFormField(
                          labelText: 'كلمة المرور المؤقتة *',
                          prefixIcon: Icons.lock_outline,
                          validator: (v) =>
                              v!.length < 8 ? '8 أحرف على الأقل' : null,
                          onSaved: (v) => pwd = v!,
                          isPassword: true,
                        ),
                        const SizedBox(height: 12),
                        AppFormField(
                          labelText: 'رقم الهاتف (اختياري)',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _phoneValidator,
                          onSaved: (v) => phone = v ?? '',
                        ),
                        const SizedBox(height: 12),
                        AppFormField(
                          labelText: 'القسم (اختياري)',
                          prefixIcon: Icons.apartment_outlined,
                          onSaved: (v) => departmentName = v ?? '',
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingTitles)
                          const SizedBox(
                            height: 84,
                            child: AppLoadingState(
                              label: 'جاري تحميل المسميات الوظيفية',
                              fallbackHeight: 84,
                            ),
                          )
                        else
                          AppDropdownField<JobTitleModel>(
                            labelText: 'المسمى الوظيفي (اختياري)',
                            prefixIcon: Icons.work_outline,
                            value: selectedJobTitle,
                            items: _activeJobTitles.map((title) {
                              return DropdownMenuItem(
                                value: title,
                                child: Text(title.name),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedJobTitle = val),
                          ),
                        const SizedBox(height: 12),
                        AppFormField(
                          labelText: 'الراتب الأساسي (اختياري)',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          onSaved: (v) => baseSalary = num.tryParse(v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        AppFormField(
                          labelText: 'المكافأة الشهرية (اختياري)',
                          prefixIcon: Icons.card_giftcard_outlined,
                          keyboardType: TextInputType.number,
                          onSaved: (v) => bonus = num.tryParse(v ?? ''),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fingerprint,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'رقم البصمة: ${widget.employee.biometricEmployeeId}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('حفظ واعتماد'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _adminService.createEmployee(
        employeeNumber: empNum,
        fullName: name,
        temporaryPassword: pwd,
        role: 'employee',
        biometricEmployeeId: widget.employee.biometricEmployeeId,
        phone: phone.trim().isNotEmpty ? phone.trim() : null,
        departmentName:
            departmentName.trim().isNotEmpty ? departmentName.trim() : null,
        jobTitleId: selectedJobTitle?.id,
        jobTitleName: selectedJobTitle?.name,
        baseSalary: baseSalary ?? 0.0,
        monthlyBonus: bonus ?? 0.0,
      );

      final employees = await _adminService.getEmployees(limit: 2000);
      final newProfileId = employees
          .firstWhere((e) => e.employeeNumber == empNum)
          .id;

      await _biometricsService.approveTemporaryEmployee(
        widget.employee.id,
        widget.employee.biometricEmployeeId,
        newProfileId,
      );

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('خطأ: $e');
    } finally {
      nameController.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = widget.employee.status == 'pending';

    return AlertDialog(
      title: const Text('تفاصيل رقم البصمة غير المعروف'),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: AppLoadingState(
                label: 'جاري الحفظ...',
                fallbackHeight: 120,
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailTile(
                      context,
                      'رقم البصمة',
                      widget.employee.biometricEmployeeId,
                      Icons.fingerprint,
                    ),
                    _detailTile(
                      context,
                      'الاسم من ملف البصمة',
                      widget.employee.employeeNameFromDevice
                                  ?.trim()
                                  .isNotEmpty ==
                              true
                          ? widget.employee.employeeNameFromDevice!.trim()
                          : 'غير متوفر',
                      Icons.person_outline,
                    ),
                    _detailTile(
                      context,
                      'عدد الحركات',
                      '${widget.employee.punchesCount}',
                      Icons.touch_app_outlined,
                    ),
                    if (widget.employee.sourceBatchId != null)
                      _detailTile(
                        context,
                        'ملف الاستيراد',
                        widget.employee.sourceBatchId!.substring(0, 8),
                        Icons.file_present_outlined,
                      ),
                    const Divider(height: 24),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: pending
                          ? AppStatusPill.warning('بحاجة اعتماد')
                          : AppStatusPill.neutral(widget.employee.status),
                    ),
                    if (pending) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _approveNew,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('اعتماد كموظف رسمي جديد'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: .55),
                          ),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('رفض رقم البصمة'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _detailTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Icon(icon),
      ),
      title: Text(label),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? _phoneValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!_phonePattern.hasMatch(value)) {
      return 'أدخل رقم الهاتف بصيغة دولية مثل +967770000000';
    }
    return null;
  }
}
