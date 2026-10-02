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
  final String? reviewResolution;
  final String? reviewedBy;
  final DateTime? reviewedAt;

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
    this.reviewResolution,
    this.reviewedBy,
    this.reviewedAt,
  });

  bool get hasUnresolvedReview {
    if (reviewStatus == 'resolved') return false;
    final issue = attendanceIssueType?.trim() ?? '';
    return status == 'needs_review' || reviewStatus == 'pending' || issue.isNotEmpty;
  }

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic value) {
      final text = value?.toString();
      if (text == null || text.trim().isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return AttendanceRecordModel(
      id: map['id'] as String,
      workDate: DateTime.parse(map['work_date'] as String),
      scheduledStart: parse(map['scheduled_start']),
      scheduledEnd: parse(map['scheduled_end']),
      checkIn: parse(map['check_in']),
      checkOut: parse(map['check_out']),
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
      reviewResolution: map['review_resolution'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: parse(map['reviewed_at']),
    );
  }
}
