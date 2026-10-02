import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'auth_service.dart';
import 'company_context_service.dart';
import 'overtime_admin_service.dart';

class AttendanceReviewCase {
  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final DateTime workDate;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final String issueType;
  final String reviewStatus;
  final String? reviewResolution;
  final String? reviewNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const AttendanceReviewCase({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.workDate,
    required this.status,
    required this.issueType,
    required this.reviewStatus,
    this.scheduledStart,
    this.scheduledEnd,
    this.checkIn,
    this.checkOut,
    this.reviewResolution,
    this.reviewNote,
    this.reviewedBy,
    this.reviewedAt,
  });
}

class AttendanceReviewService {
  Future<String> _companyId() => CompanyContextService.getCurrentCompanyId();

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Future<void> _requireReviewer() async {
    final user = await AuthService().getCurrentUser();
    final profile = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: user.$id,
    );
    final role = profile.data['role']?.toString() ?? '';
    final active = profile.data['active'] != false;
    if (!active || !AppRoles.canManageAttendance(role)) {
      throw StateError('لا تملك صلاحية مراجعة واعتماد الحضور.');
    }
  }

  bool _isPending(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    final reviewStatus = data['review_status']?.toString().trim() ?? '';
    final issue = data['attendance_issue_type']?.toString().trim() ?? '';
    if (reviewStatus == 'resolved') return false;
    return status == 'needs_review' || reviewStatus == 'pending' || issue.isNotEmpty;
  }

  Future<List<AttendanceReviewCase>> getReviews({
    String filter = 'pending',
    String? employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    await _requireReviewer();
    final companyId = await _companyId();
    final queries = <String>[
      Query.equal('company_id', companyId),
      Query.orderDesc('work_date'),
      Query.limit(1000),
    ];
    if (employeeId != null && employeeId.isNotEmpty) {
      queries.add(Query.equal('employee_id', employeeId));
    }
    if (from != null) {
      queries.add(
        Query.greaterThanEqual(
          'work_date',
          DateTime(from.year, from.month, from.day).toIso8601String().substring(0, 10),
        ),
      );
    }
    if (to != null) {
      queries.add(
        Query.lessThanEqual(
          'work_date',
          DateTime(to.year, to.month, to.day).toIso8601String().substring(0, 10),
        ),
      );
    }

    final attendance = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: queries,
    );
    final profiles = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      queries: [Query.equal('company_id', companyId), Query.limit(1000)],
    );
    final names = <String, String>{
      for (final row in profiles.rows)
        row.$id: row.data['full_name']?.toString() ?? row.$id,
    };

    final cases = <AttendanceReviewCase>[];
    for (final row in attendance.rows) {
      final data = row.data;
      final pending = _isPending(data);
      if (filter == 'pending' && !pending) continue;
      if (filter == 'resolved' && data['review_status']?.toString() != 'resolved') {
        continue;
      }
      if (filter == 'all') {
        final issue = data['attendance_issue_type']?.toString().trim() ?? '';
        final everReviewed = data['review_status']?.toString().trim().isNotEmpty == true;
        if (!pending && !everReviewed && issue.isEmpty) continue;
      }
      final employee = data['employee_id']?.toString() ?? '';
      final workDate = _parseDate(data['work_date']);
      if (employee.isEmpty || workDate == null) continue;
      cases.add(
        AttendanceReviewCase(
          id: row.$id,
          companyId: companyId,
          employeeId: employee,
          employeeName: names[employee] ?? employee,
          workDate: workDate,
          scheduledStart: _parseDate(data['scheduled_start']),
          scheduledEnd: _parseDate(data['scheduled_end']),
          checkIn: _parseDate(data['check_in']),
          checkOut: _parseDate(data['check_out']),
          status: data['status']?.toString() ?? '',
          issueType: data['attendance_issue_type']?.toString() ?? '',
          reviewStatus: data['review_status']?.toString() ?? (pending ? 'pending' : ''),
          reviewResolution: data['review_resolution']?.toString(),
          reviewNote: data['review_note']?.toString(),
          reviewedBy: data['reviewed_by']?.toString(),
          reviewedAt: _parseDate(data['reviewed_at']),
        ),
      );
    }
    return cases;
  }

  Future<void> resolveReview({
    required String attendanceId,
    required String resolution,
    required String note,
    DateTime? checkIn,
    DateTime? checkOut,
  }) async {
    await _requireReviewer();
    final companyId = await _companyId();
    final user = await AuthService().getCurrentUser();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      rowId: attendanceId,
    );
    final data = row.data;
    if (data['company_id']?.toString() != companyId) {
      throw StateError('سجل الحضور لا يتبع شركة المستخدم الحالية.');
    }
    if (data['review_status']?.toString() == 'resolved') {
      throw StateError('تم حسم حالة الحضور هذه مسبقًا.');
    }
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      throw ArgumentError('يجب كتابة ملاحظة توضح قرار المراجعة.');
    }
    final actualOutForValidation = resolution == 'present' ? (checkOut ?? _parseDate(data['check_out'])) : null; await OvertimeAdminService().validateNoApprovedOvertimeConflict(attendanceId, actualOutForValidation); if (!const {'present', 'absent', 'rest_day'}.contains(resolution)) {
      throw ArgumentError('قرار مراجعة الحضور غير صالح.');
    }

    final scheduledStart = _parseDate(data['scheduled_start']);
    final scheduledEnd = _parseDate(data['scheduled_end']);
    final update = <String, dynamic>{
      'review_status': 'resolved',
      'review_resolution': resolution,
      'review_note': cleanNote,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': user.$id,
    };

    if (resolution == 'present') {
      final actualIn = checkIn ?? _parseDate(data['check_in']);
      final actualOut = checkOut ?? _parseDate(data['check_out']);
      if (actualIn == null || actualOut == null) {
        throw ArgumentError('اعتماد الحضور يتطلب وقت دخول ووقت خروج.');
      }
      if (!actualOut.isAfter(actualIn)) {
        throw ArgumentError('وقت الخروج يجب أن يكون بعد وقت الدخول.');
      }
      var late = 0;
      var early = 0;
      var overtime = 0;
      if (scheduledStart != null) {
        late = actualIn.difference(scheduledStart).inMinutes;
        if (late < 0) late = 0;
      }
      if (scheduledEnd != null) {
        early = scheduledEnd.difference(actualOut).inMinutes;
        if (early < 0) early = 0;
        final over = actualOut.difference(scheduledEnd).inMinutes;
        if (over > 60) overtime = over;
      }
      update.addAll({
        'check_in': actualIn.toIso8601String(),
        'check_out': actualOut.toIso8601String(),
        'worked_minutes': actualOut.difference(actualIn).inMinutes,
        'credited_minutes': actualOut.difference(actualIn).inMinutes,
        'late_minutes': late,
        'early_leave_minutes': early,
        'overtime_minutes': overtime,
        'status': late > 0 || early > 0 ? 'late' : 'present',
      });
    } else {
      update.addAll({
        'check_in': null,
        'check_out': null,
        'worked_minutes': 0,
        'credited_minutes': 0,
        'late_minutes': 0,
        'early_leave_minutes': 0,
        'overtime_minutes': 0,
        'status': resolution == 'absent' ? 'absent' : 'rest_day',
      });
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      rowId: attendanceId,
      data: update,
    );
    await OvertimeAdminService().syncOvertimeForAttendance(attendanceId);
  }

  Future<int> countUnresolvedForEmployeeMonth({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final companyId = await _companyId();
    final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual('work_date', start),
        Query.lessThanEqual('work_date', end),
        Query.limit(500),
      ],
    );
    return rows.rows.where((row) => _isPending(row.data)).length;
  }
}
