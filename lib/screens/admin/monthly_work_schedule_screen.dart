import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../models/shift_model.dart';
import '../../models/employee_shift_assignment_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/shift_service.dart';
import '../../services/employee_shift_assignment_service.dart';
import '../../services/employee_work_schedule_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';

class MonthlyWorkScheduleScreen extends StatefulWidget {
  final ProfileModel profile;

  const MonthlyWorkScheduleScreen({super.key, required this.profile});

  @override
  State<MonthlyWorkScheduleScreen> createState() => _MonthlyWorkScheduleScreenState();
}

class _MonthlyWorkScheduleScreenState extends State<MonthlyWorkScheduleScreen> {
  final AdminService _adminService = AdminService();
  final ShiftService _shiftService = ShiftService();
  final EmployeeShiftAssignmentService _assignmentService = EmployeeShiftAssignmentService();
  final EmployeeWorkScheduleService _scheduleService = EmployeeWorkScheduleService();

  List<ProfileModel> _employees = [];
  List<ShiftModel> _shifts = [];

  ProfileModel? _selectedEmployee;
  EmployeeShiftAssignmentModel? _currentAssignment;

  bool _isLoading = true;
  bool _isGenerating = false;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Rest days configuration (1 = Monday, 5 = Friday, 6 = Saturday, 7 = Sunday)
  String _restDaysOption = 'friday_saturday';

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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  List<int> _getRestDaysList() {
    switch (_restDaysOption) {
      case 'friday': return [5];
      case 'saturday': return [6];
      case 'friday_saturday': return [5, 6];
      case 'none': return [];
      default: return [5, 6];
    }
  }

  Future<void> _generateSchedule() async {
    if (_selectedEmployee == null || _currentAssignment == null) return;
    
    setState(() => _isGenerating = true);
    
    try {
      await _scheduleService.generateMonthSchedule(
        companyId: widget.profile.companyId,
        employeeId: _selectedEmployee!.id,
        year: _selectedYear,
        month: _selectedMonth,
        assignment: _currentAssignment!,
        allShifts: _shifts,
        restDays: _getRestDaysList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم توليد الجدول الشهري بنجاح!', style: TextStyle(fontWeight: FontWeight.bold))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التوليد: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _getAssignmentDescription() {
    if (_currentAssignment == null) return 'لا يوجد تعيين دوام نشط';
    if (_currentAssignment!.assignmentType == 'fixed') return 'دوام ثابت';
    if (_currentAssignment!.assignmentType == 'weekly_rotation') return 'دوام متغير أسبوعياً';
    return 'غير معروف';
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
    return AppScaffold(
      title: 'توليد جدول الدوام الشهري',
      body: _isLoading && _employees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildMobileLayout(),
    );
  }

  int _getRestDaysCount(int daysInMonth) {
    return List.generate(daysInMonth, (i) => DateTime(_selectedYear, _selectedMonth, i + 1))
        .where((d) => _getRestDaysList().contains(d.weekday))
        .length;
  }

  Widget _buildMobileLayout() {
    final int daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final int restDaysCount = _getRestDaysCount(daysInMonth);
    final int workDaysCount = daysInMonth - restDaysCount;
    final isHr = AppRoles.isHr(widget.profile.role);
    
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
                              title: 'إعدادات الشهر',
                              icon: Icons.calendar_month,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppDropdownField<int>(
                                    value: _selectedYear,
                                    labelText: 'السنة',
                                    items: [2024, 2025, 2026, 2027, 2028]
                                        .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                                        .toList(),
                                    onChanged: (v) => setState(() => _selectedYear = v!),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AppDropdownField<int>(
                                    value: _selectedMonth,
                                    labelText: 'الشهر',
                                    items: List.generate(12, (i) => i + 1)
                                        .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                                        .toList(),
                                    onChanged: (v) => setState(() => _selectedMonth = v!),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AppDropdownField<String>(
                              value: _restDaysOption,
                              labelText: 'أيام الراحة الأسبوعية',
                              items: const [
                                DropdownMenuItem(value: 'friday', child: Text('الجمعة')),
                                DropdownMenuItem(value: 'saturday', child: Text('السبت')),
                                DropdownMenuItem(value: 'friday_saturday', child: Text('الجمعة والسبت')),
                                DropdownMenuItem(value: 'none', child: Text('بدون راحة')),
                              ],
                              onChanged: (v) => setState(() => _restDaysOption = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        backgroundColor: Colors.blue.shade50,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppSectionHeader(
                              title: 'ملخص التوليد',
                              icon: Icons.analytics_outlined,
                            ),
                            const SizedBox(height: 16),
                            Text('نوع الدوام الحالي: ${_getAssignmentDescription()}'),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('إجمالي الأيام: $daysInMonth'),
                                Text('أيام العمل: $workDaysCount'),
                                Text('أيام الراحة: $restDaysCount'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isHr)
                        AppLoadingButton(
                          onPressed: _currentAssignment == null ? null : _generateSchedule,
                          isLoading: _isGenerating,
                          text: 'توليد واعتماد جدول الشهر',
                          icon: Icons.calendar_month,
                        ),
                      if (_currentAssignment == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(
                            child: Text(
                              'الموظف ليس له تعيين دوام نشط. يرجى تعيين دوامه أولاً.',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
        ],
      ),
    );
  }
}
