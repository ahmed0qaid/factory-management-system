import 'package:flutter/material.dart';
import '../../../models/temporary_employee_model.dart';
import '../../../services/admin_biometrics_service.dart';
import '../../../services/admin_service.dart';
import '../../../services/job_title_service.dart';
import '../../../models/job_title_model.dart';
import '../../../widgets/common/app_dropdown_field.dart';
import '../../../widgets/common/app_form_field.dart';
import '../../../widgets/common/app_loading_state.dart';

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
    } catch (e) {
      if (mounted) setState(() => _isLoadingTitles = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الرفض'),
        content: const Text(
          'هل تريد رفض رقم البصمة هذا؟ لن يتم إنشاء موظف رسمي له.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
    // Show form to create new employee
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
      builder: (_) {
        return AlertDialog(
          title: const Text('اعتماد كموظف رسمي جديد'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppFormField(
                    labelText: 'الرقم الوظيفي *',
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    onSaved: (v) => empNum = v!,
                  ),
                  const SizedBox(height: 8),
                  AppFormField(
                    controller: nameController,
                    labelText: 'الاسم الكامل *',
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    onSaved: (v) => name = v!,
                  ),
                  const SizedBox(height: 8),
                  AppFormField(
                    labelText: 'كلمة المرور المؤقتة *',
                    validator: (v) => v!.length < 8 ? '8 أحرف على الأقل' : null,
                    onSaved: (v) => pwd = v!,
                    isPassword: true,
                  ),
                  const SizedBox(height: 8),
                  AppFormField(
                    labelText: 'رقم الهاتف (اختياري)',
                    keyboardType: TextInputType.phone,
                    validator: _phoneValidator,
                    onSaved: (v) => phone = v ?? '',
                  ),
                  const SizedBox(height: 8),
                  AppFormField(
                    labelText: 'القسم (اختياري)',
                    onSaved: (v) => departmentName = v ?? '',
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingTitles)
                    const CircularProgressIndicator()
                  else
                    AppDropdownField<JobTitleModel>(
                      labelText: 'المسمى الوظيفي (اختياري)',
                      value: selectedJobTitle,
                      items: _activeJobTitles.map((title) {
                        return DropdownMenuItem(
                          value: title,
                          child: Text(title.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedJobTitle = val),
                    ),
                  const SizedBox(height: 8),
                  AppFormField(
                    labelText: 'الراتب الأساسي (اختياري)',
                    keyboardType: TextInputType.number,
                    onSaved: (v) => baseSalary = num.tryParse(v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  AppFormField(
                    labelText: 'المكافأة الشهرية (اختياري)',
                    keyboardType: TextInputType.number,
                    onSaved: (v) => bonus = num.tryParse(v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'رقم البصمة: ${widget.employee.biometricEmployeeId}',
                    style: const TextStyle(
                      
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(context, true);
                }
              },
              child: const Text('حفظ واعتماد'),
            ),
          ],
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
        departmentName: departmentName.trim().isNotEmpty
            ? departmentName.trim()
            : null,
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
    return AlertDialog(
      title: const Text('تفاصيل رقم البصمة غير المعروف'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: AppLoadingState(label: 'جاري الحفظ...'),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('رقم البصمة'),
                    trailing: Text(
                      widget.employee.biometricEmployeeId,
                      style: const TextStyle(),
                    ),
                  ),
                  ListTile(
                    title: const Text('الاسم من ملف البصمة'),
                    trailing: Text(
                      widget.employee.employeeNameFromDevice
                                  ?.trim()
                                  .isNotEmpty ==
                              true
                          ? widget.employee.employeeNameFromDevice!.trim()
                          : 'غير متوفر',
                      style: const TextStyle(),
                    ),
                  ),
                  ListTile(
                    title: const Text('عدد الحركات'),
                    trailing: Text('${widget.employee.punchesCount}'),
                  ),
                  if (widget.employee.sourceBatchId != null)
                    ListTile(
                      title: const Text('ملف الاستيراد'),
                      trailing: Text(
                        widget.employee.sourceBatchId!.substring(0, 8),
                      ),
                    ),
                  const Divider(),
                  if (widget.employee.status == 'pending') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _approveNew,
                        icon: const Icon(Icons.person_add),
                        label: const Text('اعتماد كموظف رسمي جديد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _reject,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'رفض رقم البصمة',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Text(
                        'الحالة الحالية: ${widget.employee.status}',
                        style: const TextStyle(
                          
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ],
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

  String? _phoneValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!_phonePattern.hasMatch(value)) {
      return 'أدخل رقم الهاتف بصيغة دولية مثل +967770000000';
    }
    return null;
  }
}


