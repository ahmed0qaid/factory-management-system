import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/shift_model.dart';
import '../models/overtime_record_model.dart';
import '../models/attendance_policy_model.dart';
import '../models/temporary_employee_model.dart';
import '../services/appwrite_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_preprocessor.dart';

class AdminBiometricsService {
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

  String _normalizePunchType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';

    if (raw == 'i' || raw.contains('in') || raw.contains('دخول')) {
      return 'check_in';
    }

    if (raw == 'o' || raw.contains('out') || raw.contains('خروج')) {
      return 'check_out';
    }

    if (raw.isNotEmpty && raw.length <= 20) {
      return raw;
    }

    return 'unknown';
  }

  Future<List<ShiftModel>> getShifts(String companyId) async {
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      queries: [Query.equal('company_id', companyId)],
    );
    return docs.rows.map((d) => ShiftModel.fromMap(d.data, id: d.$id)).toList();
  }

  Future<void> commitBiometricImport({
    required String companyId,
    required String fileName,
    required List<Map<String, dynamic>> logs,
    String? shiftId,
  }) async {
    final user = await AuthService().getCurrentUser();
    final batchId = ID.unique();

    final profilesResponse = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      queries: [Query.equal('company_id', companyId), Query.limit(500)],
    );

    final profilesByBiometricId = <String, String>{};
    for (var doc in profilesResponse.rows) {
      final bioId = doc.data['biometric_employee_id']?.toString();
      if (bioId != null && bioId.isNotEmpty) {
        profilesByBiometricId[bioId] = doc.$id;
      }
    }

    int validRows = 0;
    int invalidRows = 0;

    for (var log in logs) {
      if (log['is_valid'] == true) {
        validRows++;
        final bioId = log['biometric_employee_id'].toString();
        final matchedEmployeeId = profilesByBiometricId[bioId];
        final isMatched = matchedEmployeeId != null;

        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.biometricLogsTable,
          rowId: ID.unique(),
          data: _removeNulls({
            'company_id': companyId,
            'import_batch_id': batchId,
            'biometric_employee_id': bioId,
            'employee_id': matchedEmployeeId,
            'employee_name_from_device': log['employee_name_from_device'],
            'punch_time': (log['punch_time'] as DateTime).toIso8601String(),
            'punch_type': log['punch_type'],
            'raw_line': log['raw_line'],
            'is_matched': isMatched,
            'is_processed': false,
            'created_at': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        invalidRows++;
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.biometricLogsTable,
          rowId: ID.unique(),
          data: _removeNulls({
            'company_id': companyId,
            'import_batch_id': batchId,
            'biometric_employee_id': '',
            'punch_time': DateTime.now().toIso8601String(),
            'raw_line': log['raw_line'],
            'is_matched': false,
            'is_processed': false,
            'error_message': log['error_message'],
            'created_at': DateTime.now().toIso8601String(),
          }),
        );
      }
    }

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.biometricImportBatchesTable,
      rowId: batchId,
      data: _removeNulls({
        'company_id': companyId,
        'file_name': fileName,
        'imported_by': user.$id,
        'imported_at': DateTime.now().toIso8601String(),
        'status': 'imported',
        'total_rows': logs.length,
        'valid_rows': validRows,
        'invalid_rows': invalidRows,
        'processed_rows': 0,
      }),
    );

    // Process the batch immediately
    await _processBiometricBatch(
      companyId: companyId,
      batchId: batchId,
      globalShiftId: shiftId,
    );
  }

  Future<void> _processBiometricBatch({
    required String companyId,
    required String batchId,
    String? globalShiftId,
  }) async {
    final logsResponse = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.biometricLogsTable,
      queries: [
        Query.equal('import_batch_id', batchId),
        Query.equal('is_matched', true),
        Query.equal('is_processed', false),
        Query.limit(1000),
      ],
    );

    if (logsResponse.rows.isEmpty) return;

    // 1. Get active policy
    final policyDocs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendancePoliciesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('active', true),
      ],
    );
    if (policyDocs.rows.isEmpty) throw Exception('No active policy found');
    final policy = AttendancePolicyModel.fromMap(
      policyDocs.rows.first.data,
      id: policyDocs.rows.first.$id,
    );

    // 2. Get global shift if set
    ShiftModel? globalShift;
    if (globalShiftId != null) {
      final shiftRow = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.shiftsTable,
        rowId: globalShiftId,
      );
      globalShift = ShiftModel.fromMap(shiftRow.data, id: shiftRow.$id);
    }

    // Group logs by employee
    final Map<String, List<models.Row>> empLogs = {};
    for (var doc in logsResponse.rows) {
      final empId = doc.data['employee_id'];
      if (empId != null) {
        empLogs.putIfAbsent(empId, () => []).add(doc);
      }
    }

    int processedCount = 0;

    for (var empId in empLogs.keys) {
      final punches = empLogs[empId]!;
      punches.sort(
        (a, b) => DateTime.parse(
          a.data['punch_time'],
        ).compareTo(DateTime.parse(b.data['punch_time'])),
      );

      // Group punches by physical day
      final Map<String, List<models.Row>> punchesByDay = {};
      for (var punch in punches) {
        final pt = DateTime.parse(punch.data['punch_time']);
        // If time is before 6 AM, attribute it to the previous day (handles overnight shifts ending at 06:00 AM)
        final effectiveDate = pt.hour < 6
            ? pt.subtract(const Duration(days: 1))
            : pt;
        final dateStr = effectiveDate.toIso8601String().substring(0, 10);
        punchesByDay.putIfAbsent(dateStr, () => []).add(punch);
      }

      for (var dateStr in punchesByDay.keys) {
        final dayPunches = punchesByDay[dateStr]!;

        ShiftModel? shiftToApply = globalShift;
        // If no global shift, try to find employee_shift_assignments (omitted for brevity, assume global for now)

        if (shiftToApply == null) {
          // Mark as needs review: no shift
          await _createNeedsReviewRecord(
            companyId,
            empId,
            dateStr,
            'لا توجد وردية محددة لهذا اليوم',
          );
          for (var p in dayPunches) {
            await _markProcessed(p.$id);
            processedCount++;
          }
          continue;
        }

        final workDate = DateTime.parse(dateStr);
        final sTimeParts = shiftToApply.startTime.split(':');
        final eTimeParts = shiftToApply.endTime.split(':');

        final shiftStart = DateTime(
          workDate.year,
          workDate.month,
          workDate.day,
          int.parse(sTimeParts[0]),
          int.parse(sTimeParts[1]),
        );
        var shiftEnd = DateTime(
          workDate.year,
          workDate.month,
          workDate.day,
          int.parse(eTimeParts[0]),
          int.parse(eTimeParts[1]),
        );

        if (shiftToApply.isOvernight || shiftEnd.isBefore(shiftStart)) {
          shiftEnd = shiftEnd.add(const Duration(days: 1));
        }

        final actualCheckIn = DateTime.parse(
          dayPunches.first.data['punch_time'],
        );
        final actualCheckOut = DateTime.parse(
          dayPunches.last.data['punch_time'],
        );

        if (dayPunches.length == 1) {
          // Missing check out
          await _createOrUpdateAttendance(
            companyId: companyId,
            employeeId: empId,
            dateStr: dateStr,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            checkIn: actualCheckIn,
            checkOut: null,
            status: 'needs_review',
            issueType: 'missing_check_out',
            note: 'يرجى مراجعة مدير الإنتاج لتصحيح بصمة الخروج.',
          );
        } else {
          // We have at least two punches
          int lateMinutes = 0;
          final lateDiff = actualCheckIn.difference(shiftStart).inMinutes;
          final gLate =
              shiftToApply.graceLateMinutes ?? policy.graceLateMinutes;

          if (lateDiff > gLate) {
            lateMinutes = policy.lateCalculationMode == 'full_time'
                ? lateDiff
                : (lateDiff - gLate);
          }

          int earlyLeaveMinutes = 0;
          final earlyDiff = shiftEnd.difference(actualCheckOut).inMinutes;
          final gEarly =
              shiftToApply.graceEarlyLeaveMinutes ??
              policy.graceEarlyLeaveMinutes;

          if (earlyDiff > gEarly) {
            earlyLeaveMinutes = policy.earlyLeaveCalculationMode == 'full_time'
                ? earlyDiff
                : (earlyDiff - gEarly);
          }

          int overtimeMinutes = 0;
          final overDiff = actualCheckOut.difference(shiftEnd).inMinutes;
          if (overDiff > policy.overtimeMinimumMinutes) {
            overtimeMinutes = overDiff;
          }

          String finalStatus = (lateMinutes > 0 || earlyLeaveMinutes > 0)
              ? 'late'
              : 'present';

          final attId = await _createOrUpdateAttendance(
            companyId: companyId,
            employeeId: empId,
            dateStr: dateStr,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            checkIn: actualCheckIn,
            checkOut: actualCheckOut,
            status: finalStatus,
            lateMins: lateMinutes > 0 ? lateMinutes : null,
            earlyMins: earlyLeaveMinutes > 0 ? earlyLeaveMinutes : null,
            overtimeMins: overtimeMinutes > 0 ? overtimeMinutes : null,
          );

          if (overtimeMinutes > 0 && attId != null) {
            await _createOvertimeRecord(
              companyId: companyId,
              employeeId: empId,
              attId: attId,
              workDate: workDate,
              shiftEnd: shiftEnd,
              actualCheckOut: actualCheckOut,
              overtimeMins: overtimeMinutes,
            );
          }
        }

        for (var p in dayPunches) {
          await _markProcessed(p.$id);
          processedCount++;
        }
      }
    }

    // update batch
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.biometricImportBatchesTable,
      rowId: batchId,
      data: {'processed_rows': processedCount},
    );
  }

  Future<String?> _createOrUpdateAttendance({
    required String companyId,
    required String employeeId,
    required String dateStr,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required DateTime? checkIn,
    required DateTime? checkOut,
    required String status,
    String? issueType,
    String? note,
    int? lateMins,
    int? earlyMins,
    int? overtimeMins,
  }) async {
    // check if exists
    final existResp = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', employeeId),
        Query.equal('work_date', dateStr),
      ],
    );

    int workedMins = 0;
    if (checkIn != null && checkOut != null) {
      workedMins = checkOut.difference(checkIn).inMinutes;
    }

    final data = _removeNulls({
      'company_id': companyId,
      'employee_id': employeeId,
      'work_date': dateStr,
      'shift_start': shiftStart.toIso8601String(),
      'shift_end': shiftEnd.toIso8601String(),
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'late_minutes': lateMins,
      'early_leave_minutes': earlyMins,
      'overtime_minutes': overtimeMins,
      'worked_minutes': workedMins > 0 ? workedMins : null,
      'status': status,
      'attendance_issue_type': issueType,
      'review_note': note,
      'review_status': issueType != null ? 'pending' : null,
    });

    if (existResp.rows.isNotEmpty) {
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendanceTable,
        rowId: existResp.rows.first.$id,
        data: data,
      );
      return existResp.rows.first.$id;
    } else {
      final newId = ID.unique();
      await AppwriteService.tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendanceTable,
        rowId: newId,
        data: data,
      );
      return newId;
    }
  }

  Future<void> _createOvertimeRecord({
    required String companyId,
    required String employeeId,
    required String attId,
    required DateTime workDate,
    required DateTime shiftEnd,
    required DateTime actualCheckOut,
    required int overtimeMins,
  }) async {
    // Check if overtime record already exists for this attendance
    final exist = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: [Query.equal('attendance_record_id', attId)],
    );

    if (exist.rows.isNotEmpty) return; // already recorded

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: ID.unique(),
      data: _removeNulls({
        'company_id': companyId,
        'employee_id': employeeId,
        'attendance_record_id': attId,
        'work_date': workDate.toIso8601String(),
        'shift_end': shiftEnd.toIso8601String(),
        'actual_check_out': actualCheckOut.toIso8601String(),
        'overtime_minutes': overtimeMins,
        'approval_status': 'pending',
        'payment_status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> _createNeedsReviewRecord(
    String companyId,
    String employeeId,
    String dateStr,
    String note,
  ) async {
    await _createOrUpdateAttendance(
      companyId: companyId,
      employeeId: employeeId,
      dateStr: dateStr,
      shiftStart: DateTime.now(), // dummy
      shiftEnd: DateTime.now(), // dummy
      checkIn: null,
      checkOut: null,
      status: 'needs_review',
      issueType: 'missing_both',
      note: note,
    );
  }

  Future<void> _markProcessed(String logId) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.biometricLogsTable,
      rowId: logId,
      data: {'is_processed': true},
    );
  }

  Future<List<OvertimeRecordModel>> getPendingOvertime() async {
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: [
        Query.equal('approval_status', 'pending'),
        Query.orderDesc('created_at'),
      ],
    );
    return docs.rows
        .map((d) => OvertimeRecordModel.fromMap(d.data, id: d.$id))
        .toList();
  }

  Future<void> updateOvertimeStatus(
    String overtimeId,
    String approvalStatus,
  ) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
      data: {
        'approval_status': approvalStatus,
        if (approvalStatus == 'approved')
          'approved_at': DateTime.now().toIso8601String(),
      },
    );
    // TODO: Send notification
  }

  Future<void> payOvertime(String overtimeId, num amount) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
      data: {
        'payment_status': 'paid',
        'paid_amount': amount,
        'paid_at': DateTime.now().toIso8601String(),
      },
    );
    // TODO: Send notification
  }

  Future<T> _retryOnRateLimit<T>(
    Future<T> Function() action, {
    String operationName = 'operation',
  }) async {
    var delay = const Duration(seconds: 2);

    for (var attempt = 1; attempt <= 4; attempt++) {
      try {
        return await action();
      } catch (e) {
        final message = e.toString();
        final isRateLimit = message.contains('general_rate_limit_exceeded') ||
            message.contains('Rate limit');

        if (!isRateLimit || attempt == 4) {
          rethrow;
        }

        await Future.delayed(delay);
        delay *= 2;
      }
    }

    return await action();
  }

  Future<Map<String, dynamic>> commitProcessedBiometricImport({
    required String companyId,
    required String fileName,
    required PreprocessSummary summary,
    required List<Map<String, dynamic>> rawLogs,
  }) async {
    try {
      debugPrint('IMPORT_COMMIT_STARTED');
      final batchId = ID.unique();
      final user = await AuthService().getCurrentUser();

      int logsCreated = 0;
      int logsSkipped = 0;
      int logsFailed = 0;
      int logsFailedRateLimit = 0;

      int attendanceCreated = 0;
      int attendanceSkipped = 0;
      int attendanceFailed = 0;
      int attendanceFailedRateLimit = 0;

      int temporaryCreated = 0;
      int temporaryUpdated = 0;
      int temporarySkippedDuplicate = 0;
      int temporaryFailedRateLimit = 0;

      int createdOvertime = 0;
      int skippedOvertime = 0;
      int createdNotifications = 0;
      int temporaryFailed = 0; // general failure
      final temporaryIdsWithImportedNames = <String>{};
      int matchedEmployees = 0;
      bool batchSaved = false;

      List<String> errors = [];

      Future<Set<String>> fetchAllExistingIds(String tableId) async {
        final existing = <String>{};
        String? cursor;
        while (true) {
          final queries = [Query.equal('company_id', companyId), Query.limit(1000)];
          if (cursor != null) queries.add(Query.cursorAfter(cursor));
          try {
            final res = await _retryOnRateLimit(() async => await AppwriteService.tablesDB.listRows(
              databaseId: AppConstants.databaseId, tableId: tableId, queries: queries));
            for (var doc in res.rows) existing.add(doc.$id);
            if (res.rows.length < 1000) break;
            cursor = res.rows.last.$id;
          } catch (e) {
            debugPrint('Failed to fetch cache for $tableId: $e'); break;
          }
        }
        return existing;
      }

      Future<Set<String>> fetchExistingIdsWithDateRange(String tableId, String dateField, DateTime? minD, DateTime? maxD) async {
        final existing = <String>{};
        if (minD == null || maxD == null) return existing;
        String? cursor;
        final minStr = minD.toIso8601String().substring(0, 10);
        final maxStr = maxD.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
        while (true) {
          final queries = [
            Query.equal('company_id', companyId),
            Query.greaterThanEqual(dateField, minStr),
            Query.lessThanEqual(dateField, maxStr),
            Query.limit(1000),
          ];
          if (cursor != null) queries.add(Query.cursorAfter(cursor));
          try {
            final res = await _retryOnRateLimit(() async => await AppwriteService.tablesDB.listRows(
              databaseId: AppConstants.databaseId, tableId: tableId, queries: queries));
            for (var doc in res.rows) existing.add(doc.$id);
            if (res.rows.length < 1000) break;
            cursor = res.rows.last.$id;
          } catch (e) {
            debugPrint('Failed to fetch cache for $tableId: $e'); break;
          }
        }
        return existing;
      }

      // 1. Create Batch
      debugPrint('IMPORT_CREATE_BATCH_STARTED');
      try {
        await _retryOnRateLimit(() async {
          await AppwriteService.tablesDB.createRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.biometricImportBatchesTable,
            rowId: batchId,
            data: _removeNulls({
              'company_id': companyId,
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
        debugPrint('IMPORT_CREATE_BATCH_FAILED: biometric_import_batches / $e');
        String errorString = e.toString();
        String exactReason = 'Unknown error';
        if (errorString.contains('Unknown attribute')) {
          final matches = RegExp(r'Unknown attribute "(.*?)"').firstMatch(errorString);
          exactReason = 'Unknown attribute "${matches?.group(1) ?? ''}"';
        } else if (errorString.contains('Missing required attribute')) {
          final matches = RegExp(r'Missing required attribute "(.*?)"').firstMatch(errorString);
          exactReason = 'Missing required attribute "${matches?.group(1) ?? ''}"';
        } else {
          exactReason = errorString.split('\n').first;
        }
        errors.add('فشل Batch: $exactReason');
      }

      // Preload Data (Caches)
      debugPrint('IMPORT_PRELOAD_CACHES_STARTED');
      final existingTemporaryIds = await fetchAllExistingIds(AppConstants.temporaryBiometricEmployeesTable);

      DateTime? minPunch, maxPunch;
      for (var log in rawLogs) {
        if (log['punch_time'] == null) continue;
        final d = log['punch_time'] as DateTime;
        if (minPunch == null || d.isBefore(minPunch)) minPunch = d;
        if (maxPunch == null || d.isAfter(maxPunch)) maxPunch = d;
      }

      DateTime? minWork, maxWork;
      for (var group in summary.groups) {
        final d = group.workDate;
        if (minWork == null || d.isBefore(minWork)) minWork = d;
        if (maxWork == null || d.isAfter(maxWork)) maxWork = d;
      }

      final existingLogIds = await fetchExistingIdsWithDateRange(AppConstants.biometricLogsTable, 'punch_time', minPunch, maxPunch);
      final existingAttendanceIds = await fetchExistingIdsWithDateRange(AppConstants.attendanceTable, 'work_date', minWork, maxWork);
      final existingOvertimeIds = await fetchExistingIdsWithDateRange(AppConstants.overtimeRecordsTable, 'work_date', minWork, maxWork);

      final profilesResponse = await _retryOnRateLimit(() async {
        return await AppwriteService.tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.profilesTable,
          queries: [Query.equal('company_id', companyId), Query.limit(1000)],
        );
      });

      final profilesByBiometricId = <String, String>{};
      for (var doc in profilesResponse.rows) {
        final bioId = doc.data['biometric_employee_id']?.toString();
        if (bioId != null && bioId.isNotEmpty) {
          profilesByBiometricId[bioId] = doc.$id;
        }
      }

      // 2. Insert biometric logs
      debugPrint('IMPORT_SAVE_LOGS_STARTED');
      for (var log in rawLogs) {
        if (log['is_valid'] != true || log['punch_time'] == null) {
          logsFailed++;
          continue;
        }

        final bioIdStr = log['biometric_employee_id']?.toString() ?? '';
        final pTime = (log['punch_time'] as DateTime).toIso8601String();
        final logRowId = _safeRowId('bio_${bioIdStr}_$pTime');

        if (existingLogIds.contains(logRowId)) {
          logsSkipped++;
          continue; // Fast skip!
        }
        
        try {
          await _retryOnRateLimit(() async {
            await AppwriteService.tablesDB.createRow(
              databaseId: AppConstants.databaseId,
              tableId: AppConstants.biometricLogsTable,
              rowId: logRowId,
              data: _removeNulls({
                'company_id': companyId,
                'import_batch_id': batchId,
                'biometric_employee_id': bioIdStr,
                'employee_name_from_device': log['employee_name_from_device'],
                'employee_id': log['employee_id'],
                'punch_time': pTime,
                'punch_type': _normalizePunchType(log['punch_type']),
                'raw_line': log['raw_line'] ?? '',
                'is_matched': log['employee_id'] != null,
                'is_processed': true,
                'error_message': log['error_message'],
                'created_at': DateTime.now().toIso8601String(),
              }),
            );
          });
          logsCreated++;
          existingLogIds.add(logRowId);
          await Future.delayed(const Duration(milliseconds: 50));
        } on AppwriteException catch (e) {
          if (e.code == 409 || e.type == 'document_already_exists') {
            logsSkipped++;
            existingLogIds.add(logRowId);
          } else {
            logsFailed++;
            if (errors.isEmpty || !errors.any((err) => err.startsWith('فشل Logs:'))) {
              String exactReason = 'Unknown error';
              if (e.message != null && (e.message!.contains('general_rate_limit_exceeded') || e.message!.contains('Rate limit'))) {
                logsFailedRateLimit++;
                exactReason = 'تم تجاوز الحد المسموح للطلبات أثناء حفظ بعض سجلات البصمة، أعد المحاولة بعد قليل.';
              } else if (e.message != null && e.message!.contains('Unknown attribute')) {
                final matches = RegExp(r'Unknown attribute "(.*?)"').firstMatch(e.message!);
                exactReason = 'Unknown attribute "${matches?.group(1) ?? ''}"';
              } else if (e.message != null && e.message!.contains('Missing required attribute')) {
                final matches = RegExp(r'Missing required attribute "(.*?)"').firstMatch(e.message!);
                exactReason = 'Missing required attribute "${matches?.group(1) ?? ''}"';
              } else {
                exactReason = e.message?.split('\n').first ?? '';
              }
              errors.add('فشل Logs: $exactReason');
            }
          }
        } catch (e) {
          final errMsg = e.toString();
          if (errMsg.contains('general_rate_limit_exceeded') || errMsg.contains('Rate limit')) {
             logsFailedRateLimit++;
             if (errors.isEmpty || !errors.any((err) => err.startsWith('فشل Logs:'))) {
               errors.add('فشل Logs: تم تجاوز الحد المسموح للطلبات أثناء حفظ بعض سجلات البصمة، أعد المحاولة بعد قليل.');
             }
          } else {
             logsFailed++;
             if (errors.isEmpty || !errors.any((err) => err.startsWith('فشل Logs:'))) {
               errors.add('فشل Logs: خطأ غير متوقع.');
             }
          }
        }
      }



      // 3. Process Groups
      debugPrint('IMPORT_CREATE_ATTENDANCE_STARTED');

      final unmatchedBioIds = <String>{};
      final matchedBioIds = <String>{};
      final updatedTempIds = <String>{}; // Deduplication set

      for (var group in summary.groups) {
        final mappedEmpId = profilesByBiometricId[group.biometricId];
        if (mappedEmpId == null) {
          unmatchedBioIds.add(group.biometricId);
          final employeeNameFromDevice = group.employeeName?.trim();
          if (employeeNameFromDevice != null && employeeNameFromDevice.isNotEmpty) {
            temporaryIdsWithImportedNames.add(group.biometricId);
          }
          // Unmatched employee!
          try {
            final tempId = _safeRowId('temp_${group.biometricId}');
            
            // Fast Check Cache
            if (existingTemporaryIds.contains(tempId) || updatedTempIds.contains(tempId)) {
               temporarySkippedDuplicate++;
               updatedTempIds.add(tempId);
               continue;
            }

            final nowStr = DateTime.now().toIso8601String();

            await _retryOnRateLimit(() async {
              await AppwriteService.tablesDB.createRow(
                databaseId: AppConstants.databaseId,
                tableId: AppConstants.temporaryBiometricEmployeesTable,
                rowId: tempId,
                data: _removeNulls({
                  'company_id': companyId,
                  'biometric_employee_id': group.biometricId,
                  'employee_name_from_device': employeeNameFromDevice,
                  'status': 'pending',
                  'first_seen_at': nowStr,
                  'last_seen_at': nowStr,
                  'punches_count': group.punches.length,
                  'source_batch_id': batchId,
                  'created_at': nowStr,
                  'updated_at': nowStr,
                }),
              );
            });
            temporaryCreated++;
            updatedTempIds.add(tempId);
            existingTemporaryIds.add(tempId);
            await Future.delayed(const Duration(milliseconds: 50));
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('general_rate_limit_exceeded') || msg.contains('Rate limit')) {
               temporaryFailedRateLimit++;
               if (errors.isEmpty || !errors.any((err) => err.startsWith('فشل الموظفين المؤقتين:'))) {
                 errors.add('فشل الموظفين المؤقتين: تم تجاوز الحد المسموح للطلبات أثناء تحديث بعض الموظفين المؤقتين، أعد المحاولة بعد قليل.');
               }
            } else {
               temporaryFailed++;
               if (errors.isEmpty || !errors.any((err) => err.startsWith('فشل الموظفين المؤقتين:'))) {
                 errors.add('فشل الموظفين المؤقتين: $msg');
               }
            }
          }

          continue;
        }

        final empId = mappedEmpId;
        matchedBioIds.add(group.biometricId);
        final dateStr = group.workDate.toIso8601String().substring(0, 10);

        final sStart = group.shiftStart?.toIso8601String() ?? 'none';
        final sEnd = group.shiftEnd?.toIso8601String() ?? 'none';
        final attId = _safeRowId('att_${empId}_${dateStr}_${sStart}_$sEnd');

        String status = 'present';
        String? issueType;
        String? reviewStatus;

        if (group.isAbsent) {
          status = 'absent';
        } else if (group.needsReview) {
          status = 'needs_review';
          reviewStatus = 'pending';
          if (group.actualCheckIn == null && group.actualCheckOut != null) {
            issueType = 'missing_check_in';
          } else if (group.actualCheckIn != null && group.actualCheckOut == null) {
            issueType = 'missing_check_out';
          } else if (group.actualCheckIn == null && group.actualCheckOut == null) {
            issueType = 'missing_both';
          }
        }

        int lateMinutes = 0;
        int earlyLeaveMinutes = 0;
        int workedMinutes = 0;

        final hasCompleteActualPunches = group.actualCheckIn != null && group.actualCheckOut != null;

        if (hasCompleteActualPunches && group.shiftStart != null) {
          lateMinutes = group.actualCheckIn!.difference(group.shiftStart!).inMinutes;
          if (lateMinutes < 0) lateMinutes = 0;
        }

        if (hasCompleteActualPunches && group.shiftEnd != null) {
          earlyLeaveMinutes = group.shiftEnd!.difference(group.actualCheckOut!).inMinutes;
          if (earlyLeaveMinutes < 0) earlyLeaveMinutes = 0;
        }

        if (hasCompleteActualPunches) {
          workedMinutes = group.actualCheckOut!.difference(group.actualCheckIn!).inMinutes;
          if (workedMinutes < 0) workedMinutes = 0;
        }

        // Save Attendance
        if (existingAttendanceIds.contains(attId)) {
          attendanceSkipped++;
        } else {
          try {
            await _retryOnRateLimit(() async {
              await AppwriteService.tablesDB.createRow(
                databaseId: AppConstants.databaseId,
                tableId: AppConstants.attendanceTable,
                rowId: attId,
                data: _removeNulls({
                  'company_id': companyId,
                  'employee_id': empId,
                  'work_date': dateStr,
                  if (group.shiftStart != null) 'scheduled_start': group.shiftStart!.toIso8601String(),
                  if (group.shiftEnd != null) 'scheduled_end': group.shiftEnd!.toIso8601String(),
                  if (group.actualCheckIn != null) 'check_in': group.actualCheckIn!.toIso8601String(),
                  if (group.actualCheckOut != null) 'check_out': group.actualCheckOut!.toIso8601String(),
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
                }),
              );
            });
            attendanceCreated++;
            existingAttendanceIds.add(attId);
            await Future.delayed(const Duration(milliseconds: 50));
          } on AppwriteException catch (e) {
            if (e.code == 409 || e.type == 'document_already_exists') {
              attendanceSkipped++;
              existingAttendanceIds.add(attId);
            } else {
               attendanceFailed++;
               final msg = e.toString();
               if (msg.contains('general_rate_limit_exceeded') || msg.contains('Rate limit')) {
                   attendanceFailedRateLimit++;
                   if (errors.isEmpty || !errors.any((err) => err.startsWith('Attendance:'))) {
                     errors.add('Attendance: تم تجاوز الحد المسموح للطلبات أثناء حفظ بعض سجلات الحضور، أعد المحاولة بعد قليل.');
                   }
               } else {
                   if (errors.isEmpty || !errors.any((err) => err.startsWith('Attendance:'))) {
                     errors.add('Attendance: $msg');
                   }
                   if (msg.contains('row_invalid_structure') || msg.contains('Missing required attribute')) {
                      throw Exception('فشل خطير في الحضور يمنع الاستيراد: $msg');
                   }
               }
               continue;
            }
          } catch (e) {
               attendanceFailed++;
               final msg = e.toString();
               if (msg.contains('general_rate_limit_exceeded') || msg.contains('Rate limit')) {
                   attendanceFailedRateLimit++;
                   if (errors.isEmpty || !errors.any((err) => err.startsWith('Attendance:'))) {
                     errors.add('Attendance: تم تجاوز الحد المسموح للطلبات أثناء حفظ بعض سجلات الحضور، أعد المحاولة بعد قليل.');
                   }
               } else {
                   if (errors.isEmpty || !errors.any((err) => err.startsWith('Attendance:'))) {
                     errors.add('Attendance: $msg');
                   }
               }
               continue;
          }
        }

        // Save Overtime
        if (group.expectedOvertimeMinutes > 0 && group.shiftStart != null && group.shiftEnd != null) {
          final otId = _safeRowId('ot_${empId}_${dateStr}_${sStart}_$sEnd');
          if (existingOvertimeIds.contains(otId)) {
            skippedOvertime++;
          } else {
            debugPrint('IMPORT_CREATE_OVERTIME_STARTED');
            try {
              await _retryOnRateLimit(() async {
                await AppwriteService.tablesDB.createRow(
                  databaseId: AppConstants.databaseId,
                  tableId: AppConstants.overtimeRecordsTable,
                  rowId: otId,
                  data: _removeNulls({
                    'company_id': companyId,
                    'employee_id': empId,
                    'attendance_record_id': attId,
                    'work_date': dateStr,
                    'shift_end': group.shiftEnd!.toIso8601String(),
                    'actual_check_out': group.actualCheckOut?.toIso8601String() ?? group.shiftEnd!.toIso8601String(),
                    'overtime_minutes': group.expectedOvertimeMinutes,
                    'approval_status': 'pending',
                    'payment_status': 'unpaid',
                    'created_at': DateTime.now().toIso8601String(),
                  }),
                );
              });
              createdOvertime++;
              existingOvertimeIds.add(otId);
              await Future.delayed(const Duration(milliseconds: 50));
            } on AppwriteException catch (e) {
              if (e.code == 409 || e.type == 'document_already_exists') {
                skippedOvertime++;
                existingOvertimeIds.add(otId);
              } else {
                debugPrint('IMPORT_CREATE_OVERTIME_FAILED: overtime_records / $e');
              }
            } catch (e) {
              debugPrint('IMPORT_CREATE_OVERTIME_FAILED: overtime_records / $e');
            }
          }
        }
      }

      matchedEmployees = matchedBioIds.length;

      // Create Summary Notification
      if (attendanceCreated > 0 || temporaryCreated > 0 || summary.needsReviewGroups > 0 || attendanceSkipped > 0) {
        debugPrint('IMPORT_CREATE_NOTIFICATION_STARTED');
        try {
          final notificationBody = '''
تم استيراد ملف البصمة.
سجلات حضور جديدة: $attendanceCreated
سجلات حضور موجودة مسبقًا / متخطاة: $attendanceSkipped
حالات تحتاج مراجعة: ${summary.needsReviewGroups}
حالات غياب: ${summary.absentCases}
حالات دخول بدون خروج: ${summary.missingCheckOuts}
حالات خروج بدون دخول: ${summary.missingCheckIns}
موظفون مؤقتون جدد: $temporaryCreated
موظفون مؤقتون موجودون مسبقًا / متخطون: $temporarySkippedDuplicate
'''.trim();

          await _retryOnRateLimit(() async {
            await AppwriteService.tablesDB.createRow(
              databaseId: AppConstants.databaseId,
              tableId: AppConstants.notificationsTable,
              rowId: ID.unique(),
              data: _removeNulls({
                'company_id': companyId,
                'employee_id': user.$id,
                'title': 'اكتمل استيراد البصمة',
                'body': notificationBody,
                'type': 'attendance_alert',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              }),
            );
          });
          createdNotifications++;
        } catch (e) {
          debugPrint('IMPORT_CREATE_NOTIFICATION_FAILED: notifications / $e');
        }
      }



      debugPrint('IMPORT_COMMIT_DONE');

      return {
        'batch_saved': batchSaved,
        'logs_saved': logsCreated,
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
        'created_overtime': createdOvertime,
        'skipped_overtime': skippedOvertime,
        'created_notifications': createdNotifications,
        'excel_rows_read': summary.excelRowsRead,
        'matched_employees': matchedEmployees,
        'unmatched': unmatchedBioIds.length,
        'needs_review': summary.needsReviewGroups,
        'absent_cases': summary.absentCases,
        'missing_check_in': summary.missingCheckIns,
        'missing_check_out': summary.missingCheckOuts,
        'temporary_failed': temporaryFailed,
        'temporary_with_imported_names': temporaryIdsWithImportedNames.length,
        'errors': errors,
      };
    } catch (e, st) {
      debugPrint('IMPORT_COMMIT_FAILED: $e');
      debugPrint('IMPORT_COMMIT_STACK: $st');
      rethrow;
    }
  }

  Future<List<TemporaryEmployeeModel>> getTemporaryEmployees(
    String companyId, {
    String status = 'pending',
  }) async {
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.temporaryBiometricEmployeesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('status', status),
        Query.limit(100),
        Query.orderDesc('last_seen_at'),
      ],
    );
    return docs.rows
        .map((d) => TemporaryEmployeeModel.fromMap(d.data, id: d.$id))
        .toList();
  }

  Future<void> rejectTemporaryEmployee(String tempId) async {
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
