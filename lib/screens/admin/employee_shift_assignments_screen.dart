import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/employee_shift_assignment_model.dart';
import '../../models/profile_model.dart';
import '../../models/shift_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/employee_shift_assignment_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/employee_picker_field.dart';

class EmployeeShiftAssignmentsScreen extends StatefulWidget {
  final ProfileModel profile;

  const EmployeeShiftAssignmentsScreen({super.key, required this.profile});

  @override
  State<EmployeeShiftAssignmentsScreen> createState() =>
      _EmployeeShiftAssignmentsScreenState();
}

class _EmployeeShiftAssignmentsScreenState
    extends State<EmployeeShiftAssignmentsScreen> {
  final AdminService _adminService = AdminService();
  final ShiftService _shiftService = ShiftService();
  final EmployeeShiftAssignmentService _assignmentService =
      EmployeeShiftAssignmentService();

  List<ProfileModel> _employees = [];
  List<ShiftModel> _shifts = [];

  ProfileModel? _selectedEmployee;
  EmployeeShiftAssignmentModel? _currentAssignment;

  bool _isLoading = true;
  bool _isSaving = false;

  String _assignmentType = 'fixed';
  String? _fixedShiftId;
  String? _week1ShiftId;
  String? _week2ShiftId;
  DateTime? _rotationStartDate;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _adminService.getEmployees(limit: 500),
        _shiftService.getShifts(widget.profile.companyId),
      ]);
      if (!mounted) return;
      final employees = results[0] as List<ProfileModel>;
      final shifts = results[1] as List<ShiftModel>;
      setState(() {
        _employees = employees.where((employee) => employee.active).toList();
        _shifts = shifts.where((shift) => shift.active).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل الموظفين والورديات: $error')),
      );
    }
  }

  void _onEmployeeChanged(String? employeeId) {
    if (employeeId == null) {
      setState(() {
        _selectedEmployee = null;
        _currentAssignment = null;
      });
      return;
    }
    final employee = _employees.firstWhere((item) => item.id == employeeId);
    _selectEmployee(employee);
  }

  Future<void> _selectEmployee(ProfileModel employee) async {
    setState(() {
      _selectedEmployee = employee;
      _isLoading = true;
    });

    try {
      final assignment =
          await _assignmentService.getActiveAssignment(employee.id);
      if (!mounted || _selectedEmployee?.id != employee.id) return;
      setState(() {
        _currentAssignment = assignment;
        _isLoading = false;

        if (assignment != null) {
          _assignmentType = assignment.assignmentType;
          _notesController.text = assignment.notes ?? '';

          if (_assignmentType == 'fixed') {
            _fixedShiftId = assignment.fixedShiftId;
            _week1ShiftId = null;
            _week2ShiftId = null;
            _rotationStartDate = null;
          } else {
            _fixedShiftId = null;
            _rotationStartDate = assignment.rotationStartDate;
            if (assignment.rotationPattern != null) {
              try {
                final map = jsonDecode(assignment.rotationPattern!);
                final weeks = map['weeks'] as List;
                if (weeks.isNotEmpty) _week1ShiftId = weeks[0]['shift_id'];
                if (weeks.length > 1) _week2ShiftId = weeks[1]['shift_id'];
              } catch (_) {
                _week1ShiftId = null;
                _week2ShiftId = null;
              }
            }
          }
        } else {
          _assignmentType = 'fixed';
          _fixedShiftId = null;
          _week1ShiftId = null;
          _week2ShiftId = null;
          _rotationStartDate = null;
          _notesController.clear();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل تعيين دوام الموظف: $error')),
      );
    }
  }

  Future<void> _saveAssignment() async {
    final employee = _selectedEmployee;
    if (employee == null) return;

    if (_assignmentType == 'fixed' && _fixedShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الوردية الثابتة')),
      );
      return;
    }

    if (_assignmentType == 'weekly_rotation' &&
        (_week1ShiftId == null ||
            _week2ShiftId == null ||
            _rotationStartDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تعبئة جميع بيانات التدوير الأسبوعي'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? rotationPattern;
      if (_assignmentType == 'weekly_rotation') {
        rotationPattern = jsonEncode({
          'type': 'weekly',
          'weeks': [
            {'week': 1, 'shift_id': _week1ShiftId},
            {'week': 2, 'shift_id': _week2ShiftId},
          ],
        });
      }

      final newAssignment = EmployeeShiftAssignmentModel(
        id: _currentAssignment?.id ?? '',
        companyId: widget.profile.companyId,
        employeeId: employee.id,
        assignmentType: _assignmentType,
        fixedShiftId: _assignmentType == 'fixed' ? _fixedShiftId : null,
        rotationPattern: rotationPattern,
        rotationStartDate:
            _assignmentType == 'weekly_rotation' ? _rotationStartDate : null,
        active: true,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _assignmentService.saveAssignment(newAssignment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تعيين الدوام بنجاح')),
      );
      await _selectEmployee(employee);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ تعيين الدوام: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _disableAssignment() async {
    final assignment = _currentAssignment;
    final employee = _selectedEmployee;
    if (assignment == null || employee == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تعطيل تعيين الدوام'),
            content: Text(
              'هل تريد تعطيل تعيين الدوام الحالي للموظف ${employee.fullName}؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تعطيل'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _isSaving = true);
    try {
      await _assignmentService.disableAssignment(assignment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعطيل تعيين الدوام بنجاح')),
      );
      await _selectEmployee(employee);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تعطيل تعيين الدوام: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AppRoles.isHr(widget.profile.role);

    return AppScaffold(
      title: 'تعيين دوام الموظفين',
      body: _isLoading && _employees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _buildContent(canEdit),
              ),
            ),
    );
  }

  Widget _buildContent(bool canEdit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppSectionHeader(
                  title: 'الموظف',
                  icon: Icons.person_search_outlined,
                ),
                const SizedBox(height: 12),
                EmployeePickerField(
                  employees: _employees,
                  selectedEmployeeId: _selectedEmployee?.id,
                  onChanged: _onEmployeeChanged,
                  labelText: 'اختر الموظف',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedEmployee != null)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppSectionHeader(
                              title: 'نوع الدوام',
                              icon: Icons.category_outlined,
                            ),
                            RadioListTile<String>(
                              title: const Text('دوام ثابت (وردية واحدة)'),
                              value: 'fixed',
                              groupValue: _assignmentType,
                              onChanged: canEdit
                                  ? (value) => setState(
                                        () => _assignmentType = value!,
                                      )
                                  : null,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<String>(
                              title: const Text(
                                'دوام متغير أسبوعيًا (وردتان بالتبادل)',
                              ),
                              value: 'weekly_rotation',
                              groupValue: _assignmentType,
                              onChanged: canEdit
                                  ? (value) => setState(
                                        () => _assignmentType = value!,
                                      )
                                  : null,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: _assignmentType == 'fixed'
                            ? _buildFixedForm(canEdit)
                            : _buildWeeklyRotationForm(canEdit),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: AppFormField(
                          controller: _notesController,
                          enabled: canEdit,
                          labelText: 'ملاحظات (اختياري)',
                          maxLines: 2,
                        ),
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: 18),
                        AppLoadingButton(
                          onPressed: _saveAssignment,
                          isLoading: _isSaving,
                          text: 'حفظ تعيين الدوام',
                          icon: Icons.save_outlined,
                        ),
                        if (_currentAssignment?.active == true) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _disableAssignment,
                            icon: const Icon(Icons.block_outlined),
                            label: const Text('تعطيل التعيين الحالي'),
                          ),
                        ],
                      ],
                    ],
                  ),
        ],
      ),
    );
  }

  Widget _buildFixedForm(bool canEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'الوردية الثابتة',
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 12),
        AppDropdownField<String>(
          value: _fixedShiftId,
          labelText: 'اختر الوردية',
          items: _shifts
              .map(
                (shift) => DropdownMenuItem(
                  value: shift.id,
                  child: Text(shift.name),
                ),
              )
              .toList(),
          onChanged: canEdit
              ? (value) => setState(() => _fixedShiftId = value)
              : null,
        ),
      ],
    );
  }

  Widget _buildWeeklyRotationForm(bool canEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(
          title: 'التدوير الأسبوعي',
          icon: Icons.autorenew_outlined,
        ),
        const SizedBox(height: 12),
        AppDropdownField<String>(
          value: _week1ShiftId,
          labelText: 'وردية الأسبوع الأول',
          items: _shifts
              .map(
                (shift) => DropdownMenuItem(
                  value: shift.id,
                  child: Text(shift.name),
                ),
              )
              .toList(),
          onChanged: canEdit
              ? (value) => setState(() => _week1ShiftId = value)
              : null,
        ),
        const SizedBox(height: 12),
        AppDropdownField<String>(
          value: _week2ShiftId,
          labelText: 'وردية الأسبوع الثاني',
          items: _shifts
              .map(
                (shift) => DropdownMenuItem(
                  value: shift.id,
                  child: Text(shift.name),
                ),
              )
              .toList(),
          onChanged: canEdit
              ? (value) => setState(() => _week2ShiftId = value)
              : null,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: canEdit
              ? () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _rotationStartDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) {
                    setState(() => _rotationStartDate = date);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'تاريخ بداية التدوير',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _rotationStartDate == null
                  ? 'اختر التاريخ'
                  : '${_rotationStartDate!.year}-${_rotationStartDate!.month.toString().padLeft(2, '0')}-${_rotationStartDate!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      ],
    );
  }
}
