class ShiftModel {
  final String id;
  final String companyId;
  final String name;
  final String startTime;
  final String endTime;
  final int? graceLateMinutes;
  final int? graceEarlyLeaveMinutes;
  final bool isOvernight;
  final bool active;
  final String? notes;

  ShiftModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.graceLateMinutes,
    this.graceEarlyLeaveMinutes,
    required this.isOvernight,
    required this.active,
    this.notes,
  });

  factory ShiftModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ShiftModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      name: map['name'] ?? '',
      startTime: map['start_time'] ?? '',
      endTime: map['end_time'] ?? '',
      graceLateMinutes: map['grace_late_minutes'],
      graceEarlyLeaveMinutes: map['grace_early_leave_minutes'],
      isOvernight: map['is_overnight'] ?? false,
      active: map['active'] ?? true,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'grace_late_minutes': graceLateMinutes,
      'grace_early_leave_minutes': graceEarlyLeaveMinutes,
      'is_overnight': isOvernight,
      'active': active,
      'notes': notes,
    };
  }
}
