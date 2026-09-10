import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';

class AddPenaltyScreen extends StatefulWidget {
  const AddPenaltyScreen({super.key});

  @override
  State<AddPenaltyScreen> createState() => _AddPenaltyScreenState();
}

class _AddPenaltyScreenState extends State<AddPenaltyScreen> {
  final _service = AdminService();
  late Future<List<ProfileModel>> _employeesFuture;

  ProfileModel? _selectedEmployee;
  final _categoryController = TextEditingController(text: 'جزاء إداري');
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _minutesController = TextEditingController(text: '0');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _service.getEmployees();
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الموظف')));
      return;
    }

    final amount = num.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من الصفر')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _service.addPenalty(
        companyId: _selectedEmployee!.companyId,
        employeeId: _selectedEmployee!.id,
        category: _categoryController.text.trim(),
        reason: _reasonController.text.trim(),
        amount: amount,
        minutesDeducted: int.tryParse(_minutesController.text.trim()) ?? 0,
        penaltyDate: DateTime.now().toIso8601String(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إضافة الجزاء بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
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
              title: 'خطأ',
              message: '${snapshot.error}',
              onRetry: () => setState(() => _employeesFuture = _service.getEmployees()),
            );
          }
          final employees = snapshot.data!;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppDropdownField<ProfileModel>(
                        labelText: 'الموظف',
                        value: _selectedEmployee,
                        items: employees
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  '${e.fullName} (${e.employeeNumber})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedEmployee = val),
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _categoryController,
                        labelText: 'نوع الجزاء (مثال: تأخير، غياب، مخالفة)',
                        prefixIcon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
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
                      const SizedBox(height: 32),
                      AppLoadingButton(
                        onPressed: _submit,
                        icon: Icons.gavel,
                        text: 'اعتماد الجزاء',
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
