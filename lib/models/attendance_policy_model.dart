class AttendancePolicyModel {
  final String id;
  final String companyId;
  final String name;
  final int graceLateMinutes;
  final int graceEarlyLeaveMinutes;
  final String lateCalculationMode;
  final String earlyLeaveCalculationMode;
  final int overtimeMinimumMinutes;
  final bool overtimeRequiresHrApproval;
  final bool active;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AttendancePolicyModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.graceLateMinutes,
    required this.graceEarlyLeaveMinutes,
    required this.lateCalculationMode,
    required this.earlyLeaveCalculationMode,
    required this.overtimeMinimumMinutes,
    required this.overtimeRequiresHrApproval,
    required this.active,
    required this.createdAt,
    this.updatedAt,
  });

  factory AttendancePolicyModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return AttendancePolicyModel(
      id: id ?? map['\$id'] as String? ?? '',
      companyId: map['company_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      graceLateMinutes: map['grace_late_minutes'] as int? ?? 15,
      graceEarlyLeaveMinutes: map['grace_early_leave_minutes'] as int? ?? 10,
      lateCalculationMode:
          map['late_calculation_mode'] as String? ?? 'full_time',
      earlyLeaveCalculationMode:
          map['early_leave_calculation_mode'] as String? ?? 'full_time',
      overtimeMinimumMinutes: map['overtime_minimum_minutes'] as int? ?? 30,
      overtimeRequiresHrApproval:
          map['overtime_requires_hr_approval'] as bool? ?? true,
      active: map['active'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'name': name,
      'grace_late_minutes': graceLateMinutes,
      'grace_early_leave_minutes': graceEarlyLeaveMinutes,
      'late_calculation_mode': lateCalculationMode,
      'early_leave_calculation_mode': earlyLeaveCalculationMode,
      'overtime_minimum_minutes': overtimeMinimumMinutes,
      'overtime_requires_hr_approval': overtimeRequiresHrApproval,
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
