import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/overtime_record_model.dart';
import '../models/attendance_model.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';
import 'auth_service.dart';

class OvertimeAdminService {
  Future<String> _companyId() => CompanyContextService.getCurrentCompanyId();

  Future<void> _requireRow(String overtimeId) async {
    final companyId = await _companyId();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('السجل غير موجود أو لا تملك صلاحية الوصول إليه.');
    }
  }

  Future<List<OvertimeRecordModel>> getOvertimeRecords({
    String? status, // 'pending', 'approved', 'rejected'
    String? paymentStatus, // 'paid', 'unpaid'
  }) async {
    final companyId = await _companyId();
    final queries = <String>[
      Query.equal('company_id', companyId),
      Query.orderDesc('created_at'),
      Query.limit(500),
    ];
    if (status != null) queries.add(Query.equal('approval_status', status));
    if (paymentStatus != null) queries.add(Query.equal('payment_status', paymentStatus));

    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: queries,
    );
    return docs.rows
        .map((d) => OvertimeRecordModel.fromMap(d.data, id: d.$id))
        .toList();
  }

  Future<void> updateOvertimeStatus(
    String overtimeId,
    String approvalStatus,
    String note,
  ) async {
    if (approvalStatus != 'approved' && approvalStatus != 'rejected') {
      throw ArgumentError('حالة غير صالحة.');
    }
    if (note.trim().isEmpty) {
      throw StateError('ملاحظة الاعتماد/الرفض مطلوبة.');
    }
    await _requireRow(overtimeId);
    
    final user = await AuthService().getCurrentUser();
    
    final data = <String, dynamic>{
      'approval_status': approvalStatus,
      'approval_note': note,
      'approved_by': user.$id,
      'approved_at': DateTime.now().toIso8601String(),
    };
    if (approvalStatus == 'rejected') {
      data['rejection_reason'] = note;
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
      data: data,
    );
  }

  Future<void> payOvertime(String overtimeId) async {
    await _requireRow(overtimeId);
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
    );
    if (row.data['approval_status'] != 'approved') {
      throw StateError('لا يمكن الدفع إلا للسجلات المعتمدة.');
    }
    if (row.data['payment_status'] == 'paid') {
      throw StateError('تم دفع هذا السجل مسبقاً.');
    }

    final user = await AuthService().getCurrentUser();
    
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
      data: {
        'payment_status': 'paid',
        'paid_by': user.$id,
        'paid_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> validateNoApprovedOvertimeConflict(
    String attendanceId,
    DateTime? newCheckOut,
  ) async {
    final companyId = await _companyId();
    final otQuery = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('attendance_record_id', attendanceId),
        Query.limit(1),
      ],
    );
    if (otQuery.rows.isEmpty) return;
    final ot = OvertimeRecordModel.fromMap(otQuery.rows.first.data, id: otQuery.rows.first.$id);
    
    if (ot.approvalStatus != 'pending') {
      if (newCheckOut == null) {
        throw StateError('يوجد عمل إضافي معتمد لهذا السجل. لا يمكن تعديل وقت الانصراف بصمت.');
      }
      final newOvertime = newCheckOut.difference(ot.shiftEnd).inMinutes;
      if (newOvertime != ot.overtimeMinutes) {
        throw StateError('يوجد عمل إضافي معتمد مرتبط. تعديل الانصراف سيغير قيمة الإضافي المعتمدة. يرجى المراجعة الإدارية أولاً.');
      }
    }
  }

  Future<void> syncOvertimeForAttendance(String attendanceId) async {
    final companyId = await _companyId();
    
    final attRow = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      rowId: attendanceId,
    );
    final attData = attRow.data;
    final att = AttendanceRecordModel.fromMap(attData);

    final otQuery = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('attendance_record_id', attendanceId),
        Query.limit(1),
      ],
    );
    final OvertimeRecordModel? existingOt = otQuery.rows.isNotEmpty 
        ? OvertimeRecordModel.fromMap(otQuery.rows.first.data, id: otQuery.rows.first.$id)
        : null;

    final schedQuery = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeWorkSchedulesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('employee_id', attData['employee_id']),
        Query.equal('work_date', attRow.data['work_date']),
        Query.limit(1),
      ],
    );
    
    if (schedQuery.rows.isEmpty) {
      if (existingOt != null && existingOt.approvalStatus == 'pending') {
        await AppwriteService.tablesDB.deleteRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.overtimeRecordsTable,
          rowId: existingOt.id,
        );
      }
      return;
    }

    final sched = schedQuery.rows.first.data;
    final isWorkingDay = sched['is_working_day'] as bool? ?? true;
    final scheduledEndStr = sched['scheduled_end']?.toString();

    int calculatedOvertime = 0;
    
    bool eligible = isWorkingDay &&
                    att.rawStatus != 'needs_review' &&
                    att.hasActualPresence &&
                    att.checkOut != null &&
                    scheduledEndStr != null;

    if (eligible) {
      final shiftEnd = DateTime.parse(scheduledEndStr);
      final rawDiff = att.checkOut!.difference(shiftEnd).inMinutes;
      if (rawDiff > 0) {
        calculatedOvertime = rawDiff;
      } else {
        eligible = false;
      }
    }

    if (!eligible || calculatedOvertime <= 0) {
      if (existingOt != null) {
        if (existingOt.approvalStatus == 'pending') {
          await AppwriteService.tablesDB.deleteRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.overtimeRecordsTable,
            rowId: existingOt.id,
          );
        }
      }
      return;
    }

    if (existingOt != null) {
      if (existingOt.approvalStatus == 'pending') {
        if (existingOt.overtimeMinutes != calculatedOvertime) {
          await AppwriteService.tablesDB.updateRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.overtimeRecordsTable,
            rowId: existingOt.id,
            data: {
              'overtime_minutes': calculatedOvertime,
              'actual_check_out': att.checkOut!.toIso8601String(),
              'shift_end': DateTime.parse(scheduledEndStr!).toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
        }
      }
      return;
    }

    final otId = ID.unique();
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: otId,
      data: {
        'company_id': companyId,
        'employee_id': attData['employee_id'],
        'attendance_record_id': attendanceId,
        'work_date': attRow.data['work_date'],
        'shift_end': DateTime.parse(scheduledEndStr!).toIso8601String(),
        'actual_check_out': att.checkOut!.toIso8601String(),
        'overtime_minutes': calculatedOvertime,
        'approval_status': 'pending',
        'payment_status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }
}
