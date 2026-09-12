import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/employee_picker_field.dart';

class AddPenaltyScreen extends StatefulWidget {
  const AddPenaltyScreen({super.key});

  @override
  State<AddPenaltyScreen> createState() => _AddPenaltyScreenState();
}

class _AddPenaltyScreenState extends State<AddPenaltyScreen> {
  final _service = AdminService();
  late Future<List<ProfileModel>> _employeesFuture;
  List<ProfileModel> _employees = const [];

  String? _selectedEmployeeId;
  final _categoryController = TextEditingController(text: 'جزاء إداري');
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _minutesController = TextEditingController(text: '0');
  bool _isLoading = false;

  ProfileModel? get _selectedEmployee {
    final id = _selectedEmployeeId;
    if (id == null) return null;
    for (final employee in _employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _reasonController.dispose();
    _amountController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<List<ProfileModel>> _loadEmployees() async {
    final employees = await _service.getEmployees(limit: 500);
    if (mounted)
      setState(() => _employees = employees.where((e) => e.active).toList());
    return _employees;
  }

  Future<void> _submit() async {
    final employee = _selectedEmployee;
    if (employee == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر الموظف أولًا.')));
      return;
    }

    final amount = num.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغًا صحيحًا أكبر من الصفر.')),
      );
      return;
    }
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    if (minutes < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دقائق الخصم لا يمكن أن تكون سالبة.')),
      );
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب سبب الجزاء قبل الاعتماد.')),
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الجزاء'),
            content: Text(
              'الموظف: ${employee.fullName}\nالمبلغ: $amount\nهل تريد اعتماد الجزاء؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('اعتماد'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      await _service.addPenalty(
        companyId: employee.companyId,
        employeeId: employee.id,
        category: _categoryController.text.trim(),
        reason: _reasonController.text.trim(),
        amount: amount,
        minutesDeducted: minutes,
        penaltyDate: DateTime.now().toIso8601String(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم اعتماد الجزاء بنجاح.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إضافة الجزاء: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إضافة جزاء',
      body: FutureBuilder<List<ProfileModel>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const AppLoadingState(label: 'جاري تحميل الموظفين');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل الموظفين',
              message: '${snapshot.error}',
              onRetry: () =>
                  setState(() => _employeesFuture = _loadEmployees()),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'بيانات الجزاء',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      EmployeePickerField(
                        employees: _employees,
                        selectedEmployeeId: _selectedEmployeeId,
                        labelText: 'الموظف',
                        onChanged: (value) =>
                            setState(() => _selectedEmployeeId = value),
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _categoryController,
                        labelText: 'نوع الجزاء',
                        hintText: 'مثال: تأخير، غياب، مخالفة',
                        prefixIcon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        labelText: 'المبلغ المخصوم',
                        prefixIcon: Icons.money_off_outlined,
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        labelText: 'الدقائق المخصومة (إن وجدت)',
                        prefixIcon: Icons.timer_off_outlined,
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        labelText: 'السبب والتفاصيل',
                        prefixIcon: Icons.notes_outlined,
                      ),
                      const SizedBox(height: 24),
                      AppLoadingButton(
                        onPressed: _submit,
                        icon: Icons.gavel,
                        text: 'مراجعة واعتماد الجزاء',
                        isLoading: _isLoading,
                      ),
                    ],
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
