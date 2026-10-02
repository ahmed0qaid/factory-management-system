import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';

import '../models/shift_model.dart';
import '../models/temporary_employee_model.dart';
import 'appwrite_service.dart';
import 'auth_service.dart';
import 'biometric_preprocessor.dart';
import 'canonical_attendance_schedule_service.dart';
import 'company_context_service.dart';
import 'overtime_admin_service.dart';

class AdminBiometricsService {
  final CanonicalAttendanceScheduleService _canonicalScheduleService =
      CanonicalAttendanceScheduleService();

  Map<String, dynamic> _removeNulls(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned;
  }

  String _safeRowId(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.length <= 32) return cleaned;
    return '${cleaned.substring(0, 20)}_${cleaned.hashCode.abs()}';
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _normalizePunchType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw == 'i' || raw.contains('in') || raw.contains('دخول')) {
      return 'check_in';
    }
    if (raw == 'o' || raw.contains('out') || raw.contains('خروج')) {
      return 'check_out';
    }
    if (raw.isNotEmpty && raw.length <= 20) return raw;
    return 'unknown';
  }

  Future<List<ShiftModel>> getShifts(String companyId) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(
      companyId,
    );
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      queries: [Query.equal('company_id', scopedCompanyId), Query.limit(1000)],
    );
    return docs.rows
        .map((row) => ShiftModel.fromMap(row.data, id: row.$id))
        .toList();
  }

  /// Applies employee_work_schedules to the parsed Excel preview. The
  /// expected-in/expected-out columns in Excel are never the final authority.
  Future<PreprocessSummary> prepareProcessedBiometricPreview({
    required String companyId,
    required PreprocessSummary summary,
  }) {
    return _canonicalScheduleService.apply(
      companyId: companyId,
      summary: summary,
    );
  }

  /// Backward-compatible raw import entry point. The old global-shift argument
  /// is intentionally ignored: all attendance timing is resolved from the
  /// internal daily schedule before persistence.
  Future<void> commitBiometricImport({
    required String companyId,
    required String fileName,
    required List<Map<String, dynamic>> logs,
    String? shiftId,
  }) async {
    final summary = await BiometricPreprocessor.process(
      rawLogs: logs,
      shiftMode: ShiftSelectionMode.auto,
      duplicateMode: DuplicateHandlingMode.auto,
    );
    await _canonicalScheduleService.apply(
      companyId: companyId,
      summary: summary,
    );
    await commitProcessedBiometricImport(
      companyId: companyId,
      fileName: fileName,
      summary: summary,
      rawLogs: logs,
    );
  }



  Future<T> _retryOnRateLimit<T>(Future<T> Function() action) async {
    var delay = const Duration(seconds: 2);
    for (var attempt = 1; attempt <= 4; attempt++) {
      try {
        return await action();
      } catch (e) {
        final message = e.toString();
        final isRateLimit =
            message.contains('general_rate_limit_exceeded') ||
            message.contains('Rate limit');
        if (!isRateLimit || attempt == 4) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    return action();
  }

  Future<Map<String, dynamic>> commitProcessedBiometricImport({
    required String companyId,
    required String fileName,
    required PreprocessSummary summary,
    required List<Map<String, dynamic>> rawLogs,
  }) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(
      companyId,
    );

    // Re-resolve immediately before persistence so a stale preview, changed
    // monthly schedule, or manipulated Excel expected time cannot become the
    // attendance schedule of record.
    await _canonicalScheduleService.apply(
      companyId: scopedCompanyId,
      summary: summary,
    );

    debugPrint('IMPORT_COMMIT_STARTED');
    final user = await AuthService().getCurrentUser();
    final batchId = ID.unique();

    var logsCreated = 0;
    var logsSkipped = 0;
    var logsFailed = 0;
    var logsFailedRateLimit = 0;
    var attendanceCreated = 0;
    var attendanceSkipped = 0;
    var attendanceFailed = 0;
    var attendanceFailedRateLimit = 0;
    var temporaryCreated = 0;
    var temporaryUpdated = 0;
    var temporarySkippedDuplicate = 0;
    var temporaryFailedRateLimit = 0;
    var temporaryFailed = 0;
    var createdOvertime = 0;
    var skippedOvertime = 0;
    var createdNotifications = 0;
    var skippedRestDays = 0;
    var batchSaved = false;
    final errors = <String>[];
    final temporaryIdsWithImportedNames = <String>{};

    final profilesByBiometricId = await _loadProfilesByBiometricId(
      scopedCompanyId,
    );

    try {
      await _retryOnRateLimit(() async {
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.biometricImportBatchesTable,
          rowId: batchId,
          data: _removeNulls({
            'company_id': scopedCompanyId,
            'file_name': fileName,
            'imported_by': user.$id,
            'imported_at': DateTime.now().toIso8601String(),
            'status': 'completed',
            'total_rows': summary.totalPunches,
            'valid_rows': summary.matchedEmployees,
            'invalid_rows': summary.unmatchedEmployees,
            'processed_rows': summary.matchedEmployees,
          }),
        );
      });
      batchSaved = true;
    } catch (e) {
      errors.add('فشل Batch: ${e.toString().split('\n').first}');
    }

    DateTime? minPunch;
    DateTime? maxPunch;
    for (final log in rawLogs) {
      final punch = log['punch_time'];
      if (punch is! DateTime) continue;
      if (minPunch == null || punch.isBefore(minPunch)) minPunch = punch;
      if (maxPunch == null || punch.isAfter(maxPunch)) maxPunch = punch;
    }

    DateTime? minWork;
    DateTime? maxWork;
    for (final group in summary.groups) {
      final date = group.workDate;
      if (minWork == null || date.isBefore(minWork)) minWork = date;
      if (maxWork == null || date.isAfter(maxWork)) maxWork = date;
    }

    final existingLogIds = await _fetchExistingRowIdsInDateRange(
      tableId: AppConstants.biometricLogsTable,
      dateField: 'punch_time',
      companyId: scopedCompanyId,
      minDate: minPunch,
      maxDate: maxPunch,
    );
    final existingAttendance = await _fetchAttendanceByEmployeeDate(
      companyId: scopedCompanyId,
      minDate: minWork,
      maxDate: maxWork,
    );
    final existingTemporaryIds = await _fetchAllCompanyRowIds(
      AppConstants.temporaryBiometricEmployeesTable,
      scopedCompanyId,
    );

    debugPrint('IMPORT_SAVE_LOGS_STARTED');
    for (final log in rawLogs) {
      if (log['is_valid'] != true || log['punch_time'] is! DateTime) {
        logsFailed++;
        continue;
      }

      final biometricId = log['biometric_employee_id']?.toString() ?? '';
      final punchTime = (log['punch_time'] as DateTime).toIso8601String();
      final rowId = _safeRowId('bio_${biometricId}_$punchTime');
      if (existingLogIds.contains(rowId)) {
        logsSkipped++;
        continue;
      }

      final matchedEmployeeId = profilesByBiometricId[biometricId];
      try {
        await _retryOnRateLimit(() async {
          await AppwriteService.tablesDB.createRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.biometricLogsTable,
            rowId: rowId,
            data: _removeNulls({
              'company_id': scopedCompanyId,
              'import_batch_id': batchId,
              'biometric_employee_id': biometricId,
              'employee_name_from_device': log['employee_name_from_device'],
              'employee_id': matchedEmployeeId,
              'punch_time': punchTime,
              'punch_type': _normalizePunchType(log['punch_type']),
              'raw_line': log['raw_line'] ?? '',
              'is_matched': matchedEmployeeId != null,
              'is_processed': true,
              'error_message': log['error_message'],
              'created_at': DateTime.now().toIso8601String(),
            }),
          );
        });
        logsCreated++;
        existingLogIds.add(rowId);
      } on AppwriteException catch (e) {
        if (e.code == 409 || e.type == 'document_already_exists') {
          logsSkipped++;
          existingLogIds.add(rowId);
        } else {
          logsFailed++;
          if ((e.message ?? '').contains('general_rate_limit_exceeded')) {
            logsFailedRateLimit++;
          }
          if (!errors.any((item) => item.startsWith('فشل Logs:'))) {
            errors.add('فشل Logs: ${e.message ?? e.toString()}');
          }
        }
      } catch (e) {
        logsFailed++;
        if (e.toString().contains('Rate limit')) logsFailedRateLimit++;
        if (!errors.any((item) => item.startsWith('فشل Logs:'))) {
          errors.add('فشل Logs: ${e.toString().split('\n').first}');
        }
      }
    }

    final unmatchedBioIds = <String>{};
    final matchedBioIds = <String>{};
    final touchedTemporaryIds = <String>{};

    debugPrint('IMPORT_CREATE_ATTENDANCE_STARTED');
    for (final group in summary.groups) {
      final employeeId = profilesByBiometricId[group.biometricId];
      if (employeeId == null) {
        unmatchedBioIds.add(group.biometricId);
        final importedName = group.employeeName?.trim();
        if (importedName != null && importedName.isNotEmpty) {
          temporaryIdsWithImportedNames.add(group.biometricId);
        }
        final tempId = _safeRowId('temp_${group.biometricId}');
        if (touchedTemporaryIds.contains(tempId)) {
          temporarySkippedDuplicate++;
          continue;
        }
        touchedTemporaryIds.add(tempId);
        final now = DateTime.now().toIso8601String();

        try {
          if (existingTemporaryIds.contains(tempId)) {
            await _retryOnRateLimit(() async {
              await AppwriteService.tablesDB.updateRow(
                databaseId: AppConstants.databaseId,
                tableId: AppConstants.temporaryBiometricEmployeesTable,
                rowId: tempId,
                data: _removeNulls({
                  'employee_name_from_device': importedName,
                  'last_seen_at': now,
                  'punches_count': group.punches.length,
                  'source_batch_id': batchId,
                  'updated_at': now,
                }),
              );
            });
            temporaryUpdated++;
          } else {
            await _retryOnRateLimit(() async {
              await AppwriteService.tablesDB.createRow(
                databaseId: AppConstants.databaseId,
                tableId: AppConstants.temporaryBiometricEmployeesTable,
                rowId: tempId,
                data: _removeNulls({
                  'company_id': scopedCompanyId,
                  'biometric_employee_id': group.biometricId,
                  'employee_name_from_device': importedName,
                  'status': 'pending',
                  'first_seen_at': now,
                  'last_seen_at': now,
                  'punches_count': group.punches.length,
                  'source_batch_id': batchId,
                  'created_at': now,
                  'updated_at': now,
                }),
              );
            });
            temporaryCreated++;
            existingTemporaryIds.add(tempId);
          }
        } catch (e) {
          temporaryFailed++;
          if (e.toString().contains('Rate limit')) temporaryFailedRateLimit++;
          if (!errors.any(
            (item) => item.startsWith('فشل الموظفين المؤقتين:'),
          )) {
            errors.add('فشل الموظفين المؤقتين: ${e.toString()}');
          }
        }
        continue;
      }

      matchedBioIds.add(group.biometricId);
      if (group.skipAttendance) {
        skippedRestDays++;
        continue;
      }

      final dateStr = _dateKey(group.workDate);
      final attendanceKey = '$employeeId|$dateStr';
      final existingRow = existingAttendance[attendanceKey];
      bool isUpgrade = false;
      String? existingAttendanceId;

      if (existingRow != null) {
        existingAttendanceId = existingRow['\$id'] as String?;
        final source = existingRow['source']?.toString();
        if (source == 'calendar_exception') {
          isUpgrade = true;
        } else {
          attendanceSkipped++;
          continue;
        }
      }

      var status = 'present';
      String? issueType = group.attendanceIssueType;
      String? reviewStatus;
      if (group.isAbsent) {
        status = 'absent';
      } else if (group.needsReview) {
        status = 'needs_review';
        reviewStatus = 'pending';
        issueType ??= _inferIssueType(group);
      }

      final completePunches =
          group.actualCheckIn != null && group.actualCheckOut != null;
      var lateMinutes = 0;
      var earlyLeaveMinutes = 0;
      var workedMinutes = 0;

      if (completePunches && group.shiftStart != null) {
        lateMinutes = group.actualCheckIn!
            .difference(group.shiftStart!)
            .inMinutes;
        if (lateMinutes < 0) lateMinutes = 0;
      }
      if (completePunches && group.shiftEnd != null) {
        earlyLeaveMinutes = group.shiftEnd!
            .difference(group.actualCheckOut!)
            .inMinutes;
        if (earlyLeaveMinutes < 0) earlyLeaveMinutes = 0;
      }
      if (completePunches) {
        workedMinutes = group.actualCheckOut!
            .difference(group.actualCheckIn!)
            .inMinutes;
        if (workedMinutes < 0) workedMinutes = 0;
      }
      if (status == 'present' && (lateMinutes > 0 || earlyLeaveMinutes > 0)) {
        status = 'late';
      }

      final attendanceId =
          existingAttendanceId ?? _safeRowId('att_${employeeId}_$dateStr');
      try {
        await _retryOnRateLimit(() async {
          final data = _removeNulls({
            'company_id': scopedCompanyId,
            'employee_id': employeeId,
            'work_date': dateStr,
            'scheduled_start': group.shiftStart?.toIso8601String(),
            'scheduled_end': group.shiftEnd?.toIso8601String(),
            'check_in': group.actualCheckIn?.toIso8601String(),
            'check_out': group.actualCheckOut?.toIso8601String(),
            'late_minutes': lateMinutes,
            'early_leave_minutes': earlyLeaveMinutes,
            'worked_minutes': workedMinutes,
            'credited_minutes': workedMinutes,
            'overtime_minutes': group.expectedOvertimeMinutes,
            'status': status,
            'attendance_issue_type': issueType ?? '',
            'review_status': reviewStatus ?? '',
            'review_note': group.reviewReason,
            'source': 'biometric_import',
          });

          if (isUpgrade) {
            await AppwriteService.tablesDB.updateRow(
              databaseId: AppConstants.databaseId,
              tableId: AppConstants.attendanceTable,
              rowId: attendanceId,
              data: data,
            );
          } else {
            await AppwriteService.tablesDB.createRow(
              databaseId: AppConstants.databaseId,
              tableId: AppConstants.attendanceTable,
              rowId: attendanceId,
              data: data,
            );
          }
        });
        attendanceCreated++;
        existingAttendance[attendanceKey] = {'\$id': attendanceId};
        await OvertimeAdminService().syncOvertimeForAttendance(attendanceId);
      } on AppwriteException catch (e) {
        if (e.code == 409 || e.type == 'document_already_exists') {
          attendanceSkipped++;
          existingAttendance[attendanceKey] = {'\$id': attendanceId};
        await OvertimeAdminService().syncOvertimeForAttendance(attendanceId);
          continue;
        }
        attendanceFailed++;
        if ((e.message ?? '').contains('general_rate_limit_exceeded')) {
          attendanceFailedRateLimit++;
        }
        if (!errors.any((item) => item.startsWith('Attendance:'))) {
          errors.add('Attendance: ${e.message ?? e.toString()}');
        }
        continue;
      } catch (e) {
        attendanceFailed++;
        if (e.toString().contains('Rate limit')) attendanceFailedRateLimit++;
        if (!errors.any((item) => item.startsWith('Attendance:'))) {
          errors.add('Attendance: ${e.toString().split('\n').first}');
        }
        continue;
      }
    }

    if (attendanceCreated > 0 ||
        temporaryCreated > 0 ||
        temporaryUpdated > 0 ||
        summary.needsReviewGroups > 0 ||
        attendanceSkipped > 0) {
      try {
        final notificationBody =
            '''
تم استيراد ملف البصمة بالاعتماد على جدول الدوام الداخلي.
سجلات حضور جديدة: $attendanceCreated
سجلات حضور موجودة مسبقًا / متخطاة: $attendanceSkipped
أيام راحة بدون بصمات تم تجاهلها: $skippedRestDays
حالات تحتاج مراجعة: ${summary.needsReviewGroups}
حالات غياب: ${summary.absentCases}
موظفون مؤقتون جدد: $temporaryCreated
موظفون مؤقتون محدثون: $temporaryUpdated
'''
                .trim();
        await _retryOnRateLimit(() async {
          await AppwriteService.tablesDB.createRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.notificationsTable,
            rowId: ID.unique(),
            data: {
              'company_id': scopedCompanyId,
              'employee_id': user.$id,
              'title': 'اكتمل استيراد البصمة',
              'body': notificationBody,
              'type': 'attendance_alert',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            },
          );
        });
        createdNotifications++;
      } catch (e) {
        debugPrint('IMPORT_CREATE_NOTIFICATION_FAILED: $e');
      }
    }

    debugPrint('IMPORT_COMMIT_DONE');
    return {
      'batch_saved': batchSaved,
      'logs_saved': logsCreated,
      'logs_skipped': logsSkipped,
      'logs_failed': logsFailed,
      'logsCreated': logsCreated,
      'logsSkipped': logsSkipped,
      'logsFailed': logsFailed,
      'logsFailedRateLimit': logsFailedRateLimit,
      'created_attendance': attendanceCreated,
      'skipped_attendance': attendanceSkipped,
      'attendanceCreated': attendanceCreated,
      'attendanceSkipped': attendanceSkipped,
      'attendanceFailed': attendanceFailed,
      'attendanceFailedRateLimit': attendanceFailedRateLimit,
      'created_temporary': temporaryCreated,
      'updated_temporary': temporaryUpdated,
      'temporaryCreated': temporaryCreated,
      'temporaryUpdated': temporaryUpdated,
      'temporarySkippedDuplicate': temporarySkippedDuplicate,
      'temporaryFailedRateLimit': temporaryFailedRateLimit,
      'temporary_failed': temporaryFailed,
      'created_overtime': createdOvertime,
      'skipped_overtime': skippedOvertime,
      'created_notifications': createdNotifications,
      'skipped_rest_days': skippedRestDays,
      'excel_rows_read': summary.excelRowsRead,
      'matched_employees': matchedBioIds.length,
      'unmatched': unmatchedBioIds.length,
      'needs_review': summary.needsReviewGroups,
      'absent_cases': summary.absentCases,
      'missing_check_in': summary.missingCheckIns,
      'missing_check_out': summary.missingCheckOuts,
      'temporary_with_imported_names': temporaryIdsWithImportedNames.length,
      'errors': errors,
    };
  }

  String _inferIssueType(ProcessedGroup group) {
    if (group.actualCheckIn == null && group.actualCheckOut != null) {
      return 'missing_check_in';
    }
    if (group.actualCheckIn != null && group.actualCheckOut == null) {
      return 'missing_check_out';
    }
    if (group.actualCheckIn == null && group.actualCheckOut == null) {
      return 'missing_both';
    }
    return 'needs_review';
  }

  Future<Map<String, String>> _loadProfilesByBiometricId(
    String companyId,
  ) async {
    final result = <String, String>{};
    String? cursor;
    while (true) {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        queries: [
          Query.equal('company_id', companyId),
          Query.limit(1000),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      for (final row in response.rows) {
        final biometricId = row.data['biometric_employee_id']
            ?.toString()
            .trim();
        if (biometricId != null && biometricId.isNotEmpty) {
          result[biometricId] = row.$id;
        }
      }
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return result;
  }

  Future<Set<String>> _fetchAllCompanyRowIds(
    String tableId,
    String companyId,
  ) async {
    final result = <String>{};
    String? cursor;
    while (true) {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: tableId,
        queries: [
          Query.equal('company_id', companyId),
          Query.limit(1000),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      for (final row in response.rows) result.add(row.$id);
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return result;
  }

  Future<Set<String>> _fetchExistingRowIdsInDateRange({
    required String tableId,
    required String dateField,
    required String companyId,
    required DateTime? minDate,
    required DateTime? maxDate,
  }) async {
    final result = <String>{};
    if (minDate == null || maxDate == null) return result;
    String? cursor;
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

    while (true) {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: tableId,
        queries: [
          Query.equal('company_id', companyId),
          Query.greaterThanEqual(dateField, start),
          Query.lessThan(dateField, endExclusive),
          Query.limit(1000),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      for (final row in response.rows) result.add(row.$id);
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchAttendanceByEmployeeDate({
    required String companyId,
    required DateTime? minDate,
    required DateTime? maxDate,
  }) async {
    final result = <String, Map<String, dynamic>>{};
    if (minDate == null || maxDate == null) return result;
    String? cursor;
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

    while (true) {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendanceTable,
        queries: [
          Query.equal('company_id', companyId),
          Query.greaterThanEqual('work_date', start),
          Query.lessThan('work_date', endExclusive),
          Query.limit(1000),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      for (final row in response.rows) {
        final employeeId = row.data['employee_id']?.toString();
        final workDateRaw = row.data['work_date']?.toString();
        if (employeeId == null || workDateRaw == null) continue;
        final parsed = DateTime.tryParse(workDateRaw);
        if (parsed == null) continue;
        result['$employeeId|${_dateKey(parsed)}'] = {
          '\$id': row.$id,
          ...row.data,
        };
      }
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return result;
  }

  Future<Set<String>> _fetchOvertimeAttendanceIds({
    required String companyId,
    required DateTime? minDate,
    required DateTime? maxDate,
  }) async {
    final result = <String>{};
    if (minDate == null || maxDate == null) return result;
    String? cursor;
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

    while (true) {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.overtimeRecordsTable,
        queries: [
          Query.equal('company_id', companyId),
          Query.greaterThanEqual('work_date', start),
          Query.lessThan('work_date', endExclusive),
          Query.limit(1000),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      for (final row in response.rows) {
        final attendanceId = row.data['attendance_record_id']?.toString();
        if (attendanceId != null && attendanceId.isNotEmpty) {
          result.add(attendanceId);
        }
      }
      if (response.rows.length < 1000) break;
      cursor = response.rows.last.$id;
    }
    return result;
  }

  Future<void> _requireCurrentCompanyRow({
    required String tableId,
    required String rowId,
  }) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: tableId,
      rowId: rowId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('لا يمكن تنفيذ العملية على بيانات شركة أخرى.');
    }
  }

  Future<List<TemporaryEmployeeModel>> getTemporaryEmployees(
    String companyId, {
    String status = 'pending',
  }) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(
      companyId,
    );
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.temporaryBiometricEmployeesTable,
      queries: [
        Query.equal('company_id', scopedCompanyId),
        Query.equal('status', status),
        Query.limit(100),
        Query.orderDesc('last_seen_at'),
      ],
    );
    return docs.rows
        .map((row) => TemporaryEmployeeModel.fromMap(row.data, id: row.$id))
        .toList();
  }

  Future<void> rejectTemporaryEmployee(String tempId) async {
    await _requireCurrentCompanyRow(
      tableId: AppConstants.temporaryBiometricEmployeesTable,
      rowId: tempId,
    );
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.temporaryBiometricEmployeesTable,
      rowId: tempId,
      data: {
        'status': 'rejected',
        'rejected_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> approveTemporaryEmployee(
    String tempId,
    String biometricId,
    String profileId,
  ) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    await _requireCurrentCompanyRow(
      tableId: AppConstants.temporaryBiometricEmployeesTable,
      rowId: tempId,
    );
    final profile = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: profileId,
    );
    if (profile.data['company_id']?.toString() != companyId) {
      throw StateError('الموظف الرسمي لا يتبع شركة المستخدم الحالية.');
    }
    final savedBiometricId =
        profile.data['biometric_employee_id']?.toString().trim() ?? '';
    if (savedBiometricId != biometricId.trim()) {
      throw StateError('رقم البصمة في الملف لا يطابق ملف الموظف الرسمي.');
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.temporaryBiometricEmployeesTable,
      rowId: tempId,
      data: {
        'status': 'approved',
        'linked_profile_id': profileId,
        'approved_at': DateTime.now().toIso8601String(),
      },
    );
  }
}
