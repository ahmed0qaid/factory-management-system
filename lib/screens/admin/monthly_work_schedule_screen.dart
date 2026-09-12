import 'package:flutter/material.dart';

import '../../models/employee_shift_assignment_model.dart';
import '../../models/profile_model.dart';
import '../../models/shift_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../services/employee_shift_assignment_service.dart';
import '../../services/employee_work_schedule_service.dart';
import '../../services/shift_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/employee_picker_field.dart';

class MonthlyWorkScheduleScreen extends StatefulWidget {
  final ProfileModel profile;

  const MonthlyWorkScheduleScreen({super.key, required this.profile});

  @override
  State<MonthlyWorkScheduleScreen> createState() =>
      _MonthlyWorkScheduleScreenState();
}

class _MonthlyWorkScheduleScreenState extends State<MonthlyWorkScheduleScreen> {
  final AdminService _adminService = AdminService();
  final ShiftService _shiftService = ShiftService();
  final EmployeeShiftAssignmentService _assignmentService =
      EmployeeShiftAssignmentService();
  final EmployeeWorkScheduleService _scheduleService =
      EmployeeWorkScheduleService();

  List<ProfileModel> _employees = [];
  List<ShiftModel> _shifts = [];

  ProfileModel? _selectedEmployee;
  EmployeeShiftAssignmentModel? _currentAssignment;

  bool _isLoading = true;
  bool _isGenerating = false;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String _restDaysOption = 'friday_saturday';

  @override
  void initState() {
    super.initState();
    _loadData();
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
        SnackBar(content: Text('تعذر تحميل بيانات جدول الدوام: $error')),
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
      final assignment = await _assignmentService.getActiveAssignment(
        employee.id,
      );
      if (!mounted || _selectedEmployee?.id != employee.id) return;
      setState(() {
        _currentAssignment = assignment;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل تعيين دوام الموظف: $error')),
      );
    }
  }

  List<int> _getRestDaysList() {
    return switch (_restDaysOption) {
      'friday' => [DateTime.friday],
      'saturday' => [DateTime.saturday],
      'friday_saturday' => [DateTime.friday, DateTime.saturday],
      'none' => <int>[],
      _ => [DateTime.friday, DateTime.saturday],
    };
  }

  Future<void> _generateSchedule() async {
    final employee = _selectedEmployee;
    final assignment = _currentAssignment;
    if (employee == null || assignment == null) return;

    final monthLabel = _monthNames[_selectedMonth - 1];
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('توليد جدول الدوام'),
            content: Text(
              'سيتم توليد جدول $monthLabel $_selectedYear للموظف ${employee.fullName} وفق التعيين الحالي وأيام الراحة المحددة. هل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('توليد الجدول'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _isGenerating = true);
    try {
      await _scheduleService.generateMonthSchedule(
        companyId: widget.profile.companyId,
        employeeId: employee.id,
        year: _selectedYear,
        month: _selectedMonth,
        assignment: assignment,
        allShifts: _shifts,
        restDays: _getRestDaysList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم توليد جدول $monthLabel $_selectedYear للموظف ${employee.fullName} بنجاح.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر توليد جدول الدوام: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _getAssignmentDescription() {
    final assignment = _currentAssignment;
    if (assignment == null) return 'لا يوجد تعيين دوام نشط';
    return switch (assignment.assignmentType) {
      'fixed' => 'دوام ثابت',
      'weekly_rotation' => 'دوام متغير أسبوعيًا',
      _ => 'نوع دوام غير معروف',
    };
  }

  int _getRestDaysCount(int daysInMonth) {
    return List.generate(
      daysInMonth,
      (index) => DateTime(_selectedYear, _selectedMonth, index + 1),
    ).where((date) => _getRestDaysList().contains(date.weekday)).length;
  }

  static const _monthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  List<int> get _yearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(7, (index) => currentYear - 2 + index);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AppRoles.canConfigureAttendance(widget.profile.role);
    return AppScaffold(
      title: 'جدول الدوام الشهري',
      body: _isLoading && _employees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: _buildContent(canManage),
              ),
            ),
    );
  }

  Widget _buildContent(bool canManage) {
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final restDaysCount = _getRestDaysCount(daysInMonth);
    final workDaysCount = daysInMonth - restDaysCount;
    final colors = Theme.of(context).colorScheme;

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
                  title: 'اختيار الموظف',
                  icon: Icons.person_search_outlined,
                ),
                const SizedBox(height: 12),
                EmployeePickerField(
                  employees: _employees,
                  selectedEmployeeId: _selectedEmployee?.id,
                  onChanged: _onEmployeeChanged,
                  labelText: 'الموظف',
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
                              title: 'إعدادات الفترة',
                              icon: Icons.calendar_month_outlined,
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 480;
                                final year = AppDropdownField<int>(
                                  value: _selectedYear,
                                  labelText: 'السنة',
                                  items: _yearOptions
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value.toString()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: canManage
                                      ? (value) => setState(
                                          () => _selectedYear = value!,
                                        )
                                      : null,
                                );
                                final month = AppDropdownField<int>(
                                  value: _selectedMonth,
                                  labelText: 'الشهر',
                                  items: List.generate(12, (index) => index + 1)
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(_monthNames[value - 1]),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: canManage
                                      ? (value) => setState(
                                          () => _selectedMonth = value!,
                                        )
                                      : null,
                                );
                                if (compact) {
                                  return Column(
                                    children: [
                                      year,
                                      const SizedBox(height: 12),
                                      month,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: year),
                                    const SizedBox(width: 12),
                                    Expanded(child: month),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            AppDropdownField<String>(
                              value: _restDaysOption,
                              labelText: 'أيام الراحة الأسبوعية',
                              items: const [
                                DropdownMenuItem(
                                  value: 'friday',
                                  child: Text('الجمعة'),
                                ),
                                DropdownMenuItem(
                                  value: 'saturday',
                                  child: Text('السبت'),
                                ),
                                DropdownMenuItem(
                                  value: 'friday_saturday',
                                  child: Text('الجمعة والسبت'),
                                ),
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('بدون يوم راحة ثابت'),
                                ),
                              ],
                              onChanged: canManage
                                  ? (value) =>
                                        setState(() => _restDaysOption = value!)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        backgroundColor: colors.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        borderColor: colors.primary.withValues(alpha: 0.18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppSectionHeader(
                              title: 'معاينة الجدول قبل التوليد',
                              icon: Icons.analytics_outlined,
                            ),
                            const SizedBox(height: 12),
                            Text('نوع الدوام: ${_getAssignmentDescription()}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text('إجمالي الأيام: $daysInMonth'),
                                ),
                                Chip(label: Text('أيام العمل: $workDaysCount')),
                                Chip(
                                  label: Text('أيام الراحة: $restDaysCount'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_currentAssignment == null)
                        AppCard(
                          borderColor: colors.error.withValues(alpha: 0.35),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: colors.error),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'لا يوجد تعيين دوام نشط لهذا الموظف. عيّن ورديته أولًا ثم ارجع لتوليد الجدول الشهري.',
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (canManage)
                        AppLoadingButton(
                          onPressed: _generateSchedule,
                          isLoading: _isGenerating,
                          text: 'توليد جدول الشهر',
                          icon: Icons.calendar_month_outlined,
                        )
                      else
                        const AppCard(
                          child: Text(
                            'هذه الشاشة للعرض فقط حسب صلاحيات حسابك.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
        ],
      ),
    );
  }
}
