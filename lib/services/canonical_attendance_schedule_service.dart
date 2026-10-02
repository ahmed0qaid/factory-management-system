import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/employee_work_schedule_model.dart';
import '../models/shift_model.dart';
import 'appwrite_service.dart';
import 'biometric_preprocessor.dart';
import 'company_context_service.dart';

/// Applies the internally generated employee_work_schedules to biometric
/// import groups. Excel expected-time columns and legacy default shifts are
/// treated as provisional input only; this service replaces them with the
/// persisted daily schedule before preview or attendance persistence.
class CanonicalAttendanceScheduleService {
  static String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _scheduleKey(String employeeId, DateTime date) {
    return '$employeeId|${_dateKey(date)}';
  }

  Future<PreprocessSummary> apply({
    required String companyId,
    required PreprocessSummary summary,
  }) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);

    if (summary.groups.isEmpty) {
      return summary;
    }

    final profiles = await _loadProfiles(scopedCompanyId);
    final profilesByBiometricId = <String, String>{};
    for (final row in profiles) {
      final biometricId = row.data['biometric_employee_id']?.toString().trim();
      if (biometricId != null && biometricId.isNotEmpty) {
        profilesByBiometricId[biometricId] = row.$id;
      }
    }

    DateTime? minDate;
    DateTime? maxDate;
    for (final group in summary.groups) {
      final date = DateTime(
        group.workDate.year,
        group.workDate.month,
        group.workDate.day,
      );
      if (minDate == null || date.isBefore(minDate)) minDate = date;
      if (maxDate == null || date.isAfter(maxDate)) maxDate = date;
    }

    final schedules = await _loadSchedules(
      scopedCompanyId,
      minDate!,
      maxDate!,
    );
    final schedulesByEmployeeDate = <String, EmployeeWorkScheduleModel>{};
    for (final row in schedules) {
      final schedule = EmployeeWorkScheduleModel.fromMap(
        row.data,
        id: row.$id,
      );
      schedulesByEmployeeDate[
        _scheduleKey(schedule.employeeId, schedule.workDate)
      ] = schedule;
    }

    final shifts = await _loadShifts(scopedCompanyId);
    final shiftsById = <String, ShiftModel>{
      for (final shift in shifts) shift.id: shift,
    };

    final matchedBioIds = <String>{};
    final unmatchedBioIds = <String>{};

    for (final group in summary.groups) {
      _resetCanonicalState(group);

      final employeeId = profilesByBiometricId[group.biometricId];
      if (employeeId == null) {
        unmatchedBioIds.add(group.biometricId);
        group.suggestedShift = null;
        group.shiftStart = null;
        group.shiftEnd = null;
        group.isAbsent = false;
        group.needsReview = false;
        group.reviewReason = 'رقم البصمة غير مرتبط بموظف رسمي.';
        continue;
      }

      matchedBioIds.add(group.biometricId);
      final schedule = schedulesByEmployeeDate[
        _scheduleKey(employeeId, group.workDate)
      ];

      if (schedule == null) {
        group.suggestedShift = null;
        group.shiftStart = null;
        group.shiftEnd = null;
        group.isAbsent = false;
        group.needsReview = true;
        group.attendanceIssueType = 'missing_schedule';
        group.reviewReason =
            'لا يوجد جدول دوام داخلي لهذا الموظف في هذا اليوم.';
        continue;
      }

      group.canonicalScheduleId = schedule.id;
      group.canonicalScheduleResolved = true;
      group.isScheduledWorkingDay = schedule.isWorkingDay;
      group.workDate = DateTime(
        schedule.workDate.year,
        schedule.workDate.month,
        schedule.workDate.day,
      );

      if (!schedule.isWorkingDay) {
        group.suggestedShift = null;
        group.shiftStart = null;
        group.shiftEnd = null;
        group.isAbsent = false;
        group.expectedOvertimeMinutes = 0;

        final hasAnyPunch =
            group.actualCheckIn != null || group.actualCheckOut != null;
        if (hasAnyPunch) {
          group.needsReview = true;
          group.attendanceIssueType = 'rest_day_punch';
          group.reviewReason =
              'تم العثور على بصمة في يوم راحة حسب جدول الدوام الداخلي.';
        } else {
          group.needsReview = false;
          group.skipAttendance = true;
          group.reviewReason = 'يوم راحة حسب جدول الدوام الداخلي.';
        }
        continue;
      }

      final scheduledStart = schedule.scheduledStart;
      final scheduledEnd = schedule.scheduledEnd;
      if (scheduledStart == null ||
          scheduledEnd == null ||
          !scheduledEnd.isAfter(scheduledStart)) {
        group.suggestedShift = null;
        group.shiftStart = scheduledStart;
        group.shiftEnd = scheduledEnd;
        group.isAbsent = false;
        group.needsReview = true;
        group.attendanceIssueType = 'invalid_schedule';
        group.reviewReason =
            'جدول الدوام الداخلي لهذا اليوم ناقص أو يحتوي وقتًا غير صالح.';
        continue;
      }

      group.shiftStart = scheduledStart;
      group.shiftEnd = scheduledEnd;

      final shift = schedule.shiftId == null
          ? null
          : shiftsById[schedule.shiftId!];
      group.suggestedShift = ShiftDefinition(
        id: schedule.shiftId ?? schedule.id,
        name: shift?.name ?? 'جدول الدوام الداخلي',
        startHour: scheduledStart.hour,
        endHour: scheduledEnd.hour,
        windowStartHour: scheduledStart.hour,
        windowEndHour: scheduledEnd.hour,
      );

      final hasCheckIn = group.actualCheckIn != null;
      final hasCheckOut = group.actualCheckOut != null;

      if (!hasCheckIn && !hasCheckOut) {
        group.isAbsent = true;
        group.needsReview = false;
        group.reviewReason = 'غياب حسب جدول الدوام الداخلي.';
      } else if (!hasCheckIn && hasCheckOut) {
        group.isAbsent = false;
        group.needsReview = true;
        group.attendanceIssueType = 'missing_check_in';
        group.reviewReason = 'لم يتم العثور على بصمة دخول.';
      } else if (hasCheckIn && !hasCheckOut) {
        group.isAbsent = false;
        group.needsReview = true;
        group.attendanceIssueType = 'missing_check_out';
        group.reviewReason = 'لم يتم العثور على بصمة خروج.';
      } else {
        group.isAbsent = false;
        group.needsReview = false;
        group.reviewReason = '';

        final overtime = group.actualCheckOut!
            .difference(scheduledEnd)
            .inMinutes;
        if (overtime > BiometricPreprocessor.overtimeMinimumTriggerMinutes) {
          group.expectedOvertimeMinutes = overtime;
        }
      }
    }

    _recalculateSummary(
      summary,
      matchedBioIds: matchedBioIds,
      unmatchedBioIds: unmatchedBioIds,
    );
    return summary;
  }

  void _resetCanonicalState(ProcessedGroup group) {
    group.canonicalScheduleId = null;
    group.canonicalScheduleResolved = false;
    group.isScheduledWorkingDay = true;
    group.skipAttendance = false;
    group.attendanceIssueType = null;
    group.expectedOvertimeMinutes = 0;
  }

  void _recalculateSummary(
    PreprocessSummary summary, {
    required Set<String> matchedBioIds,
    required Set<String> unmatchedBioIds,
  }) {
    summary.matchedEmployees = matchedBioIds.length;
    summary.unmatchedEmployees = unmatchedBioIds.length;
    summary.needsReviewGroups = 0;
    summary.missingCheckIns = 0;
    summary.missingCheckOuts = 0;
    summary.expectedOvertimeCases = 0;
    summary.absentCases = 0;
    summary.autoDetectedShifts = 0;

    for (final group in summary.groups) {
      if (!matchedBioIds.contains(group.biometricId)) continue;
      if (group.needsReview) summary.needsReviewGroups++;
      if (group.attendanceIssueType == 'missing_check_in') {
        summary.missingCheckIns++;
      }
      if (group.attendanceIssueType == 'missing_check_out') {
        summary.missingCheckOuts++;
      }
      if (group.expectedOvertimeMinutes > 0) {
        summary.expectedOvertimeCases++;
      }
      if (group.isAbsent) summary.absentCases++;
      if (group.canonicalScheduleResolved && group.isScheduledWorkingDay) {
        summary.autoDetectedShifts++;
      }
    }
  }

  Future<List<dynamic>> _loadProfiles(String companyId) async {
    final rows = <dynamic>[];
    String? cursor;
    while (true) {
      final queries = [
        Query.equal('company_id', companyId),
        Query.limit(1000),
        if (cursor != null) Query.cursorAfter(cursor),
      ];
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        queries: queries,
      );
      rows.addAll(response.rows);
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return rows;
  }

  Future<List<dynamic>> _loadSchedules(
    String companyId,
    DateTime minDate,
    DateTime maxDate,
  ) async {
    final rows = <dynamic>[];
    final start = DateTime(
      minDate.year,
      minDate.month,
      minDate.day,
    ).toIso8601String();
    final endExclusive = DateTime(
      maxDate.year,
      maxDate.month,
      maxDate.day,
    ).add(const Duration(days: 1)).toIso8601String();

    String? cursor;
    while (true) {
      final queries = [
        Query.equal('company_id', companyId),
        Query.greaterThanEqual('work_date', start),
        Query.lessThan('work_date', endExclusive),
        Query.limit(1000),
        if (cursor != null) Query.cursorAfter(cursor),
      ];
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeWorkSchedulesTable,
        queries: queries,
      );
      rows.addAll(response.rows);
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return rows;
  }

  Future<List<ShiftModel>> _loadShifts(String companyId) async {
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      queries: [Query.equal('company_id', companyId), Query.limit(1000)],
    );
    return rows.rows
        .map((row) => ShiftModel.fromMap(row.data, id: row.$id))
        .toList();
  }
}
