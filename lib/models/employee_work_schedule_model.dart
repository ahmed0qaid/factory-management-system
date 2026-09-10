class EmployeeWorkScheduleModel {
  final String id;
  final String companyId;
  final String employeeId;
  final DateTime workDate;
  final String? shiftId;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final bool isWorkingDay;
  final String? notes;

  EmployeeWorkScheduleModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.workDate,
    this.shiftId,
    this.scheduledStart,
    this.scheduledEnd,
    required this.isWorkingDay,
    this.notes,
  });

  factory EmployeeWorkScheduleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return EmployeeWorkScheduleModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      workDate: DateTime.parse(map['work_date']),
      shiftId: map['shift_id'],
      scheduledStart: map['scheduled_start'] != null ? DateTime.parse(map['scheduled_start']) : null,
      scheduledEnd: map['scheduled_end'] != null ? DateTime.parse(map['scheduled_end']) : null,
      isWorkingDay: map['is_working_day'] ?? true,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'employee_id': employeeId,
      'work_date': workDate.toIso8601String(),
      'shift_id': shiftId,
      'scheduled_start': scheduledStart?.toIso8601String(),
      'scheduled_end': scheduledEnd?.toIso8601String(),
      'is_working_day': isWorkingDay,
      'notes': notes,
    };
  }
}
