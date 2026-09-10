class LeaveModel {
  final String id;
  final String companyId;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  LeaveModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  factory LeaveModel.fromMap(Map<String, dynamic> map) {
    return LeaveModel(
      id: map['\$id'] ?? '',
      companyId: map['company_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      leaveType: map['leave_type'] ?? '',
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      reason: map['reason'],
      status: map['status'] ?? 'pending',
      reviewedBy: map['reviewed_by'],
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
