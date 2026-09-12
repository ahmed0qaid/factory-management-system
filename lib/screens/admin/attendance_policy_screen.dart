import 'package:flutter/material.dart';

import '../../models/attendance_policy_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';

class AttendancePolicyScreen extends StatefulWidget {
  const AttendancePolicyScreen({super.key});

  @override
  State<AttendancePolicyScreen> createState() => _AttendancePolicyScreenState();
}

class _AttendancePolicyScreenState extends State<AttendancePolicyScreen> {
  final _adminService = AdminService();
  bool _isLoading = true;
  bool _isSaving = false;
  AttendancePolicyModel? _policy;

  final _formKey = GlobalKey<FormState>();

  late int _graceLateMinutes;
  late int _graceEarlyLeaveMinutes;
  late String _lateCalculationMode;
  late String _earlyLeaveCalculationMode;
  late int _overtimeMinimumMinutes;
  late bool _overtimeRequiresHrApproval;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null) {
        _policy = await _adminService.getActiveAttendancePolicy('company_main');

        _graceLateMinutes = _policy!.graceLateMinutes;
        _graceEarlyLeaveMinutes = _policy!.graceEarlyLeaveMinutes;
        _lateCalculationMode = _policy!.lateCalculationMode;
        _earlyLeaveCalculationMode = _policy!.earlyLeaveCalculationMode;
        _overtimeMinimumMinutes = _policy!.overtimeMinimumMinutes;
        _overtimeRequiresHrApproval = _policy!.overtimeRequiresHrApproval;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السياسة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final updatedPolicy = AttendancePolicyModel(
        id: _policy!.id,
        companyId: _policy!.companyId,
        name: _policy!.name,
        graceLateMinutes: _graceLateMinutes,
        graceEarlyLeaveMinutes: _graceEarlyLeaveMinutes,
        lateCalculationMode: _lateCalculationMode,
        earlyLeaveCalculationMode: _earlyLeaveCalculationMode,
        overtimeMinimumMinutes: _overtimeMinimumMinutes,
        overtimeRequiresHrApproval: _overtimeRequiresHrApproval,
        active: _policy!.active,
        createdAt: _policy!.createdAt,
      );

      await _adminService.updateAttendancePolicy(updatedPolicy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ السياسة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'سياسة الدوام',
        body: AppLoadingState(label: 'جاري تحميل سياسة الدوام'),
      );
    }

    if (_policy == null) {
      return const AppScaffold(
        title: 'سياسة الدوام',
        body: AppEmptyState(
          title: 'لا توجد سياسة دوام',
          message: 'لم يتم العثور على سياسة دوام مفعلة حاليًا.',
          icon: Icons.rule_outlined,
        ),
      );
    }

    return AppScaffold(
      title: 'إعدادات سياسة الدوام',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionHeader(
                          title: 'تأخير الحضور (الصباح)',
                          icon: Icons.sunny,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppFormField(
                          initialValue: _graceLateMinutes.toString(),
                          labelText: 'مدة السماح للتأخير (دقائق)',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.timer_outlined,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'مطلوب' : null,
                          onSaved: (val) => _graceLateMinutes = int.parse(val!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppDropdownField<String>(
                          value: _lateCalculationMode,
                          labelText: 'طريقة احتساب التأخير عند تجاوز السماح',
                          prefixIcon: Icons.calculate_outlined,
                          items: const [
                            DropdownMenuItem(
                              value: 'full_time',
                              child: Text('احتساب كامل وقت التأخير من البداية'),
                            ),
                            DropdownMenuItem(
                              value: 'after_grace_only',
                              child: Text('احتساب ما بعد مدة السماح فقط'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _lateCalculationMode = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionHeader(
                          title: 'الخروج المبكر (المساء)',
                          icon: Icons.nights_stay_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppFormField(
                          initialValue: _graceEarlyLeaveMinutes.toString(),
                          labelText: 'مدة السماح للخروج المبكر (دقائق)',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.timer_outlined,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'مطلوب' : null,
                          onSaved: (val) =>
                              _graceEarlyLeaveMinutes = int.parse(val!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppDropdownField<String>(
                          value: _earlyLeaveCalculationMode,
                          labelText: 'طريقة احتساب الخروج المبكر',
                          prefixIcon: Icons.calculate_outlined,
                          items: const [
                            DropdownMenuItem(
                              value: 'full_time',
                              child: Text('احتساب الخروج المبكر كاملًا'),
                            ),
                            DropdownMenuItem(
                              value: 'after_grace_only',
                              child: Text('احتساب ما بعد مدة السماح فقط'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _earlyLeaveCalculationMode = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionHeader(
                          title: 'الوقت الإضافي (Overtime)',
                          icon: Icons.more_time,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppFormField(
                          initialValue: _overtimeMinimumMinutes.toString(),
                          labelText:
                              'الحد الأدنى لاحتساب الإضافي بعد الدوام (دقائق)',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.timer_outlined,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'مطلوب' : null,
                          onSaved: (val) =>
                              _overtimeMinimumMinutes = int.parse(val!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          title: const Text(
                            'هل الإضافي يحتاج موافقة الموارد البشرية؟',
                          ),
                          subtitle: const Text(
                            'إذا كان مفعلاً فلن يُعتمد الإضافي تلقائياً في الراتب',
                          ),
                          contentPadding: EdgeInsets.zero,
                          value: _overtimeRequiresHrApproval,
                          onChanged: (val) => setState(
                            () => _overtimeRequiresHrApproval = val,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppLoadingButton(
                    onPressed: _savePolicy,
                    text: 'حفظ الإعدادات',
                    icon: Icons.save_outlined,
                    isLoading: _isSaving,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
