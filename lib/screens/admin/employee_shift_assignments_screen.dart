import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../models/shift_model.dart';
import '../../models/employee_shift_assignment_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/shift_service.dart';
import '../../services/employee_shift_assignment_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';

class EmployeeShiftAssignmentsScreen extends StatefulWidget {
  final ProfileModel profile;
  
  const EmployeeShiftAssignmentsScreen({super.key, required this.profile});

  @override
  State<EmployeeShiftAssignmentsScreen> createState() => _EmployeeShiftAssignmentsScreenState();
}

class _EmployeeShiftAssignmentsScreenState extends State<EmployeeShiftAssignmentsScreen> {
  final AdminService _adminService = AdminService();
  final ShiftService _shiftService = ShiftService();
  final EmployeeShiftAssignmentService _assignmentService = EmployeeShiftAssignmentService();
  
  List<ProfileModel> _employees = [];
  List<ShiftModel> _shifts = [];
  
  ProfileModel? _selectedEmployee;
  EmployeeShiftAssignmentModel? _currentAssignment;
  
  bool _isLoading = true;
  bool _isSaving = false;

  // Form State
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final emps = await _adminService.getEmployees();
      final shs = await _shiftService.getShifts(widget.profile.companyId);
      
      if (!mounted) return;
      setState(() {
        _employees = emps.where((e) => e.active).toList();
        _shifts = shs.where((s) => s.active).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _selectEmployee(ProfileModel employee) async {
    setState(() {
      _selectedEmployee = employee;
      _isLoading = true;
    });
    
    try {
      final assignment = await _assignmentService.getActiveAssignment(employee.id);
      if (!mounted) return;
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
              } catch (_) {}
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _saveAssignment() async {
    if (_selectedEmployee == null) return;
    
    if (_assignmentType == 'fixed' && _fixedShiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الوردية الثابتة')));
      return;
    }
    
    if (_assignmentType == 'weekly_rotation') {
      if (_week1ShiftId == null || _week2ShiftId == null || _rotationStartDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة جميع بيانات التدوير الأسبوعي')));
        return;
      }
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
          ]
        });
      }

      final newAssignment = EmployeeShiftAssignmentModel(
        id: _currentAssignment?.id ?? '',
        companyId: widget.profile.companyId,
        employeeId: _selectedEmployee!.id,
        assignmentType: _assignmentType,
        fixedShiftId: _assignmentType == 'fixed' ? _fixedShiftId : null,
        rotationPattern: rotationPattern,
        rotationStartDate: _assignmentType == 'weekly_rotation' ? _rotationStartDate : null,
        active: true,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await _assignmentService.saveAssignment(newAssignment);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تعيين الدوام بنجاح')));
        // Reload current employee data quietly
        _selectEmployee(_selectedEmployee!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _disableAssignment() async {
    if (_currentAssignment == null) return;
    
    setState(() => _isSaving = true);
    try {
      await _assignmentService.disableAssignment(_currentAssignment!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التعطيل بنجاح')));
        _selectEmployee(_selectedEmployee!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showEmployeeSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'اختر موظفاً',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(emp.fullName.isNotEmpty ? emp.fullName[0] : 'م'),
                        ),
                        title: Text(emp.fullName),
                        subtitle: Text(emp.employeeNumber),
                        onTap: () {
                          Navigator.pop(ctx);
                          _selectEmployee(emp);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHr = AppRoles.isHr(widget.profile.role);
    
    return AppScaffold(
      title: 'تعيين دوام الموظفين',
      body: _isLoading && _employees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildMobileLayout(isHr),
    );
  }

  Widget _buildMobileLayout(bool isHr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppSectionHeader(
                  title: 'الموظف',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                if (_selectedEmployee == null)
                  FilledButton.icon(
                    onPressed: _showEmployeeSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('ابحث واختر موظف'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(_selectedEmployee!.fullName.isNotEmpty ? _selectedEmployee!.fullName[0] : 'م'),
                    ),
                    title: Text(_selectedEmployee!.fullName),
                    subtitle: Text(_selectedEmployee!.employeeNumber),
                    trailing: IconButton(
                      icon: const Icon(Icons.change_circle, color: Colors.blue),
                      onPressed: _showEmployeeSearch,
                      tooltip: 'تغيير الموظف',
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Form Area
          if (_selectedEmployee != null)
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppSectionHeader(
                              title: 'نوع الدوام',
                              icon: Icons.category_outlined,
                            ),
                            const SizedBox(height: 16),
                            RadioListTile<String>(
                              title: const Text('دوام ثابت (وردية واحدة)'),
                              value: 'fixed',
                              groupValue: _assignmentType,
                              onChanged: isHr ? (v) => setState(() => _assignmentType = v!) : null,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<String>(
                              title: const Text('دوام متغير أسبوعياً (وردتين بالتبادل)'),
                              value: 'weekly_rotation',
                              groupValue: _assignmentType,
                              onChanged: isHr ? (v) => setState(() => _assignmentType = v!) : null,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dynamic Form based on Type
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: _assignmentType == 'fixed' 
                            ? _buildFixedForm(isHr) 
                            : _buildWeeklyRotationForm(isHr),
                      ),
                      const SizedBox(height: 16),
                      
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: AppFormField(
                          controller: _notesController,
                          enabled: isHr,
                          labelText: 'ملاحظات (اختياري)',
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (isHr)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppLoadingButton(
                              onPressed: _saveAssignment,
                              isLoading: _isSaving,
                              text: 'حفظ التعيين',
                              icon: Icons.save,
                            ),
                            if (_currentAssignment != null && _currentAssignment!.active) ...[
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _isSaving ? null : _disableAssignment,
                                icon: const Icon(Icons.stop_circle, color: Colors.red),
                                label: const Text('تعطيل التعيين', style: TextStyle(color: Colors.red, fontSize: 16)),
                              ),
                            ]
                          ],
                        ),
                    ],
                  ),
        ],
      ),
    );
  }

  Widget _buildFixedForm(bool isHr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الوردية الثابتة', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AppDropdownField<String>(
          value: _fixedShiftId,
          labelText: 'اختر الوردية',
          items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
          onChanged: isHr ? (v) => setState(() => _fixedShiftId = v) : null,
        ),
      ],
    );
  }

  Widget _buildWeeklyRotationForm(bool isHr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إعداد التدوير الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AppDropdownField<String>(
          value: _week1ShiftId,
          labelText: 'وردية الأسبوع الأول',
          items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
          onChanged: isHr ? (v) => setState(() => _week1ShiftId = v) : null,
        ),
        const SizedBox(height: 16),
        AppDropdownField<String>(
          value: _week2ShiftId,
          labelText: 'وردية الأسبوع الثاني',
          items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
          onChanged: isHr ? (v) => setState(() => _week2ShiftId = v) : null,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: isHr ? () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _rotationStartDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              setState(() => _rotationStartDate = date);
            }
          } : null,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'تاريخ بداية التدوير (متى يبدأ الأسبوع الأول؟)',
              border: OutlineInputBorder(),
            ),
            child: Text(
              _rotationStartDate != null 
                  ? '${_rotationStartDate!.year}-${_rotationStartDate!.month.toString().padLeft(2,'0')}-${_rotationStartDate!.day.toString().padLeft(2,'0')}'
                  : 'اختر التاريخ',
            ),
          ),
        ),
      ],
    );
  }
}
