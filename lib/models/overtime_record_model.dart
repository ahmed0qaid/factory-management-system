class OvertimeRecordModel {
  final String id;
  final String companyId;
  final String employeeId;
  final String? attendanceRecordId;
  final DateTime workDate;
  final DateTime shiftEnd;
  final DateTime actualCheckOut;
  final int overtimeMinutes;
  final num? overtimeAmount;
  final String approvalStatus; // pending, approved, rejected
  final String paymentStatus; // unpaid, paid
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? paidBy;
  final DateTime? paidAt;
  final num? paidAmount;
  final DateTime createdAt;

  OvertimeRecordModel({
    required this.id,
    required this.companyId,
    required this.employeeId,
    this.attendanceRecordId,
    required this.workDate,
    required this.shiftEnd,
    required this.actualCheckOut,
    required this.overtimeMinutes,
    this.overtimeAmount,
    required this.approvalStatus,
    required this.paymentStatus,
    this.approvedBy,
    this.approvedAt,
    this.paidBy,
    this.paidAt,
    this.paidAmount,
    required this.createdAt,
  });

  factory OvertimeRecordModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return OvertimeRecordModel(
      id: id ?? map['\$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      attendanceRecordId: map['attendance_record_id'],
      workDate: DateTime.parse(map['work_date']),
      shiftEnd: DateTime.parse(map['shift_end']),
      actualCheckOut: DateTime.parse(map['actual_check_out']),
      overtimeMinutes: map['overtime_minutes'] ?? 0,
      overtimeAmount: map['overtime_amount'],
      approvalStatus: map['approval_status'] ?? 'pending',
      paymentStatus: map['payment_status'] ?? 'unpaid',
      approvedBy: map['approved_by'],
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'])
          : null,
      paidBy: map['paid_by'],
      paidAt: map['paid_at'] != null ? DateTime.parse(map['paid_at']) : null,
      paidAmount: map['paid_amount'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
