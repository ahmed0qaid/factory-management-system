class LeaveModel {
  final String id;
  final String companyId;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final String status;
  final bool? isPaid;
  final String? reviewNote;
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
    this.isPaid,
    this.reviewNote,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
  bool get isUnpaid => isApproved && isPaid == false;

  factory LeaveModel.fromMap(Map<String, dynamic> map) {
    return LeaveModel(
      id: (map['id'] ?? map[r'$id'] ?? '').toString(),
      companyId: map['company_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      leaveType: map['leave_type']?.toString() ?? '',
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      reason: map['reason']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      isPaid: map['is_paid'] as bool?,
      reviewNote: map['review_note']?.toString(),
      reviewedBy: map['reviewed_by']?.toString(),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }
}
