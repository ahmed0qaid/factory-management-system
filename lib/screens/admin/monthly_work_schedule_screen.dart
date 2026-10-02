import 'package:flutter/material.dart';

import '../../models/employee_shift_assignment_model.dart';
import '../../models/employee_work_schedule_model.dart';
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
import '../../widgets/common/app_status_pill.dart';
import '../../widgets/common/employee_picker_field.dart';

class MonthlyWorkScheduleScreen extends StatefulWidget {
  final ProfileModel profile;

  const MonthlyWorkScheduleScreen({super.key, required this.profile});

  @override
  State<MonthlyWorkScheduleScreen> createState() =>
      _MonthlyWorkScheduleScreenState();
}

class _MonthlyWorkScheduleScreenState extends State<MonthlyWorkScheduleScreen> {
  final _adminService = AdminService();
  final _shiftService = ShiftService();
  final _assignmentService = EmployeeShiftAssignmentService();
  final _scheduleService = EmployeeWorkScheduleService();

  List<ProfileModel> _employees = [];
  List<ShiftModel> _shifts = [];
  Map<String, EmployeeWorkScheduleModel> _monthSchedules = {};

  ProfileModel? _selectedEmployee;
  EmployeeShiftAssignmentModel? _currentAssignment;

  bool _isLoading = true;
  bool _isScheduleLoading = false;
  bool _isGenerating = false;
  String? _editingScheduleId;

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
      setState(() {
        // Keep inactive/terminated employees visible for historical review.
        _employees = results[0] as List<ProfileModel>;
        _shifts = (results[1] as List<ShiftModel>)
            .where((shift) => shift.active)
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _message('تعذر تحميل بيانات جدول الدوام: $error');
    }
  }

  void _onEmployeeChanged(String? employeeId) {
    if (employeeId == null) {
      setState(() {
        _selectedEmployee = null;
        _currentAssignment = null;
        _monthSchedules = {};
      });
      return;
    }
    final employee = _employees.firstWhere((item) => item.id == employeeId);
    _selectEmployee(employee);
  }

  Future<void> _selectEmployee(ProfileModel employee) async {
    setState(() {
      _selectedEmployee = employee;
      _currentAssignment = null;
      _monthSchedules = {};
      _isScheduleLoading = true;
    });

    try {
      final results = await Future.wait<dynamic>([
        _assignmentService.getActiveAssignment(employee.id),
        _scheduleService.getMonthSchedules(
          widget.profile.companyId,
          employee.id,
          _selectedYear,
          _selectedMonth,
        ),
      ]);
      if (!mounted || _selectedEmployee?.id != employee.id) return;
      setState(() {
        _currentAssignment = results[0] as EmployeeShiftAssignmentModel?;
        _monthSchedules =
            results[1] as Map<String, EmployeeWorkScheduleModel>;
        _isScheduleLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isScheduleLoading = false);
      _message('تعذر تحميل جدول الموظف: $error');
    }
  }

  Future<void> _changePeriod({int? year, int? month}) async {
    setState(() {
      if (year != null) _selectedYear = year;
      if (month != null) _selectedMonth = month;
    });
    await _loadMonthSchedules();
  }

  Future<void> _loadMonthSchedules() async {
    final employee = _selectedEmployee;
    if (employee == null) return;
    setState(() => _isScheduleLoading = true);
    try {
      final schedules = await _scheduleService.getMonthSchedules(
        widget.profile.companyId,
        employee.id,
        _selectedYear,
        _selectedMonth,
      );
      if (!mounted || _selectedEmployee?.id != employee.id) return;
      setState(() {
        _monthSchedules = schedules;
        _isScheduleLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isScheduleLoading = false);
      _message('تعذر تحديث عرض الجدول: $error');
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
    if (!employee.active || employee.employmentStatus != 'active') {
      _message('لا يمكن توليد جدول جديد لموظف غير نشط.');
      return;
    }

    final manualCount = _monthSchedules.values
        .where((item) => item.isManualOverride)
        .length;
    final monthLabel = _monthNames[_selectedMonth - 1];
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('توليد جدول الدوام'),
            content: Text(
              'سيتم توليد جدول $monthLabel $_selectedYear للموظف ${employee.fullName}. '
              '${manualCount > 0 ? 'يوجد $manualCount يوم معدل يدويًا وسيتم الاحتفاظ به دون تغيير.' : ''}',
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
      await _loadMonthSchedules();
      if (mounted) {
        _message('تم توليد جدول $monthLabel $_selectedYear بنجاح.');
      }
    } catch (error) {
      if (mounted) _message('تعذر توليد جدول الدوام: $error');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _editDay(EmployeeWorkScheduleModel schedule) async {
    var isWorkingDay = schedule.isWorkingDay;
    String? selectedShiftId = schedule.shiftId;
    var startTime = schedule.scheduledStart == null
        ? null
        : TimeOfDay.fromDateTime(schedule.scheduledStart!);
    var endTime = schedule.scheduledEnd == null
        ? null
        : TimeOfDay.fromDateTime(schedule.scheduledEnd!);
    final notesController = TextEditingController(text: schedule.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void applyShift(String? shiftId) {
            selectedShiftId = shiftId;
            if (shiftId == null) return;
            final shift = _shifts.firstWhere((item) => item.id == shiftId);
            startTime = _parseTime(shift.startTime);
            endTime = _parseTime(shift.endTime);
          }

          return AlertDialog(
            title: Text('مراجعة يوم ${_dateLabel(schedule.workDate)}'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('يوم عمل'),
                      subtitle: Text(
                        isWorkingDay
                            ? 'سيتم احتساب اليوم ضمن جدول العمل'
                            : 'اليوم راحة / غير مجدول للعمل',
                      ),
                      value: isWorkingDay,
                      onChanged: (value) {
                        setDialogState(() {
                          isWorkingDay = value;
                          if (!value) {
                            selectedShiftId = null;
                            startTime = null;
                            endTime = null;
                          }
                        });
                      },
                    ),
                    if (isWorkingDay) ...[
                      const SizedBox(height: 12),
                      AppDropdownField<String>(
                        value: _shifts.any((s) => s.id == selectedShiftId)
                            ? selectedShiftId
                            : null,
                        labelText: 'الوردية',
                        items: _shifts
                            .map(
                              (shift) => DropdownMenuItem(
                                value: shift.id,
                                child: Text(
                                  '${shift.name} (${shift.startTime} - ${shift.endTime})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => applyShift(value)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.login_outlined),
                              label: Text(
                                'البداية: ${startTime?.format(context) ?? '--:--'}',
                              ),
                              onPressed: () async {
                                final value = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      startTime ?? const TimeOfDay(hour: 8, minute: 0),
                                );
                                if (value != null) {
                                  setDialogState(() => startTime = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout_outlined),
                              label: Text(
                                'النهاية: ${endTime?.format(context) ?? '--:--'}',
                              ),
                              onPressed: () async {
                                final value = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      endTime ?? const TimeOfDay(hour: 16, minute: 0),
                                );
                                if (value != null) {
                                  setDialogState(() => endTime = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة اليوم',
                        hintText: 'سبب التعديل أو وصف يوم الراحة',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    if (schedule.isManualOverride) ...[
                      const SizedBox(height: 12),
                      AppStatusPill.warning('هذا اليوم معدل يدويًا'),
                    ],
                  ],
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
                  if (isWorkingDay &&
                      (selectedShiftId == null ||
                          startTime == null ||
                          endTime == null)) {
                    _message('اختر الوردية ووقت البداية والنهاية.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('حفظ التعديل'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) {
      notesController.dispose();
      return;
    }

    DateTime? start;
    DateTime? end;
    if (isWorkingDay) {
      start = _combine(schedule.workDate, startTime!);
      end = _combine(schedule.workDate, endTime!);
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    }

    final updated = EmployeeWorkScheduleModel(
      id: schedule.id,
      companyId: schedule.companyId,
      employeeId: schedule.employeeId,
      workDate: schedule.workDate,
      shiftId: isWorkingDay ? selectedShiftId : null,
      scheduledStart: start,
      scheduledEnd: end,
      isWorkingDay: isWorkingDay,
      notes: notesController.text.trim(),
      isManualOverride: true,
      updatedAt: DateTime.now(),
      updatedBy: widget.profile.id,
    );
    notesController.dispose();

    setState(() => _editingScheduleId = schedule.id);
    try {
      await _scheduleService.updateDailySchedule(updated);
      await _loadMonthSchedules();
      if (mounted) _message('تم حفظ تعديل اليوم ولن تستبدله إعادة التوليد.');
    } catch (error) {
      if (mounted) _message('تعذر حفظ تعديل اليوم: $error');
    } finally {
      if (mounted) setState(() => _editingScheduleId = null);
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
                constraints: const BoxConstraints(maxWidth: 980),
                child: _buildContent(canManage),
              ),
            ),
    );
  }

  Widget _buildContent(bool canManage) {
    final employee = _selectedEmployee;
    final colors = Theme.of(context).colorScheme;
    final schedules = _monthSchedules.values.toList()
      ..sort((a, b) => a.workDate.compareTo(b.workDate));
    final workDays = schedules.where((item) => item.isWorkingDay).length;
    final restDays = schedules.length - workDays;
    final manualDays = schedules.where((item) => item.isManualOverride).length;

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
                  selectedEmployeeId: employee?.id,
                  onChanged: _onEmployeeChanged,
                  labelText: 'الموظف',
                ),
                if (employee != null && !employee.active) ...[
                  const SizedBox(height: 10),
                  Text(
                    'الحالة: ${employee.employmentStatusLabel} — العرض التاريخي متاح، لكن توليد جدول جديد متوقف.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (employee != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader(
                    title: 'الفترة والتوليد',
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdownField<int>(
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
                          onChanged: (value) => _changePeriod(year: value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDropdownField<int>(
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
                          onChanged: (value) => _changePeriod(month: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<String>(
                    value: _restDaysOption,
                    labelText: 'أيام الراحة المستخدمة عند التوليد',
                    items: const [
                      DropdownMenuItem(value: 'friday', child: Text('الجمعة')),
                      DropdownMenuItem(value: 'saturday', child: Text('السبت')),
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
                        ? (value) => setState(() => _restDaysOption = value!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text('نوع التعيين: ${_getAssignmentDescription()}'),
                  if (_currentAssignment == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'لا يوجد تعيين وردية نشط لهذا الموظف.',
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  if (canManage &&
                      _currentAssignment != null &&
                      employee.active &&
                      employee.employmentStatus == 'active') ...[
                    const SizedBox(height: 16),
                    AppLoadingButton(
                      onPressed: _generateSchedule,
                      isLoading: _isGenerating,
                      text: schedules.isEmpty
                          ? 'توليد جدول الشهر'
                          : 'إعادة توليد الأيام غير المعدلة يدويًا',
                      icon: Icons.calendar_month_outlined,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isScheduleLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (schedules.isEmpty)
              AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_view_month_outlined,
                      size: 42,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    const Text('لم يتم توليد جدول لهذه الفترة بعد.'),
                  ],
                ),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSectionHeader(
                      title: 'ملخص الجدول المحفوظ',
                      icon: Icons.analytics_outlined,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('الأيام: ${schedules.length}')),
                        Chip(label: Text('عمل: $workDays')),
                        Chip(label: Text('راحة: $restDays')),
                        Chip(label: Text('تعديل يدوي: $manualDays')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    final shift = _shiftById(schedule.shiftId);
                    final busy = _editingScheduleId == schedule.id;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(schedule.workDate.day.toString()),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_weekdayName(schedule.workDate.weekday)} — ${_dateLabel(schedule.workDate)}',
                            ),
                          ),
                          if (schedule.isManualOverride)
                            AppStatusPill.warning('يدوي'),
                        ],
                      ),
                      subtitle: Text(
                        schedule.isWorkingDay
                            ? '${shift?.name ?? 'وردية غير معروفة'} • ${_timeRange(schedule)}${schedule.notes?.trim().isNotEmpty == true ? '\n${schedule.notes}' : ''}'
                            : 'راحة${schedule.notes?.trim().isNotEmpty == true ? ' • ${schedule.notes}' : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: canManage
                          ? IconButton(
                              tooltip: 'مراجعة / تعديل اليوم',
                              onPressed: busy ? null : () => _editDay(schedule),
                              icon: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.edit_calendar_outlined),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  ShiftModel? _shiftById(String? id) {
    if (id == null) return null;
    for (final shift in _shifts) {
      if (shift.id == id) return shift;
    }
    return null;
  }

  String _timeRange(EmployeeWorkScheduleModel schedule) {
    if (schedule.scheduledStart == null || schedule.scheduledEnd == null) {
      return '--:-- - --:--';
    }
    return '${_two(schedule.scheduledStart!.hour)}:${_two(schedule.scheduledStart!.minute)} - ${_two(schedule.scheduledEnd!.hour)}:${_two(schedule.scheduledEnd!.minute)}';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  DateTime _combine(DateTime date, TimeOfDay time) => DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );

  String _dateLabel(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}';

  String _two(int value) => value.toString().padLeft(2, '0');

  String _weekdayName(int weekday) => const {
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
  }[weekday]!;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
}
