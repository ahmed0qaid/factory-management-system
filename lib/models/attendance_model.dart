class AttendanceRecordModel {
  final String id;
  final DateTime workDate;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int workedMinutes;
  final int creditedMinutes;
  final int overtimeMinutes;
  final String status;
  final String? notes;
  final String? attendanceIssueType;
  final String? reviewNote;
  final String? reviewStatus;

  AttendanceRecordModel({
    required this.id,
    required this.workDate,
    required this.status,
    required this.lateMinutes,
    required this.earlyLeaveMinutes,
    required this.workedMinutes,
    required this.creditedMinutes,
    required this.overtimeMinutes,
    this.scheduledStart,
    this.scheduledEnd,
    this.checkIn,
    this.checkOut,
    this.notes,
    this.attendanceIssueType,
    this.reviewNote,
    this.reviewStatus,
  });

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    DateTime? parse(String? value) =>
        value == null ? null : DateTime.parse(value);
    return AttendanceRecordModel(
      id: map['id'] as String,
      workDate: DateTime.parse(map['work_date'] as String),
      scheduledStart: parse(map['scheduled_start'] as String?),
      scheduledEnd: parse(map['scheduled_end'] as String?),
      checkIn: parse(map['check_in'] as String?),
      checkOut: parse(map['check_out'] as String?),
      lateMinutes: map['late_minutes'] as int? ?? 0,
      earlyLeaveMinutes: map['early_leave_minutes'] as int? ?? 0,
      workedMinutes: map['worked_minutes'] as int? ?? 0,
      creditedMinutes: map['credited_minutes'] as int? ?? 0,
      overtimeMinutes: map['overtime_minutes'] as int? ?? 0,
      status: map['status'] as String? ?? 'incomplete',
      notes: map['notes'] as String?,
      attendanceIssueType: map['attendance_issue_type'] as String?,
      reviewNote: map['review_note'] as String?,
      reviewStatus: map['review_status'] as String?,
    );
  }
}
