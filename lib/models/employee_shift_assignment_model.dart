class EmployeeShiftAssignmentModel {
  final String id;
  final String companyId;
  final String employeeId;
  final String assignmentType; // 'fixed' or 'weekly_rotation'
  final String? fixedShiftId;
  final String? rotationPattern;
  final DateTime? rotationStartDate;
  final bool active;
  final String? notes;

  EmployeeShiftAssignmentModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.assignmentType,
    this.fixedShiftId,
    this.rotationPattern,
    this.rotationStartDate,
    required this.active,
    this.notes,
  });

  factory EmployeeShiftAssignmentModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return EmployeeShiftAssignmentModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      assignmentType: map['assignment_type'] ?? 'fixed',
      fixedShiftId: map['fixed_shift_id'],
      rotationPattern: map['rotation_pattern'],
      rotationStartDate: map['rotation_start_date'] != null ? DateTime.parse(map['rotation_start_date']) : null,
      active: map['active'] ?? true,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'employee_id': employeeId,
      'assignment_type': assignmentType,
      'fixed_shift_id': fixedShiftId,
      'rotation_pattern': rotationPattern,
      'rotation_start_date': rotationStartDate?.toIso8601String(),
      'active': active,
      'notes': notes,
    };
  }
}
