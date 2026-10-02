import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import '../models/factory_stoppage_model.dart';
import '../models/leave_model.dart';
import '../models/profile_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';
import 'notification_service.dart';

class LeaveStoppageService {
  final NotificationService _notifications = NotificationService();

  Map<String, dynamic> _data(models.Row row) => {...row.data, 'id': row.$id};

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _covers(DateTime start, DateTime end, DateTime day) {
    final normalized = _day(day);
    return !normalized.isBefore(_day(start)) && !normalized.isAfter(_day(end));
  }

  Future<ProfileModel> _requireManager() async {
    final actor = await CompanyContextService.getCurrentProfile();
    if (!actor.active) {
      throw StateError('الحساب الإداري غير نشط.');
    }
    if (!AppRoles.canManageLeaveRequests(actor.role)) {
      throw StateError('لا تملك صلاحية إدارة الإجازات وتوقفات المصنع.');
    }
    return actor;
  }

  Future<models.Row> _requireCompanyRow({
    required String tableId,
    required String rowId,
    required String companyId,
  }) async {
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: tableId,
      rowId: rowId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('السجل لا يتبع شركة المستخدم الحالية.');
    }
    return row;
  }

  Future<List<LeaveModel>> getLeaveRequests({String? status}) async {
    final actor = await _requireManager();
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('company_id', actor.companyId),
        if (status != null) Query.equal('status', status),
        Query.orderDesc('created_at'),
        Query.limit(500),
      ],
    );
    return response.rows.map((row) => LeaveModel.fromMap(_data(row))).toList();
  }

  Future<void> approveLeave({
    required String leaveId,
    required bool isPaid,
    required String reviewNote,
  }) async {
    final note = reviewNote.trim();
    if (note.isEmpty) throw ArgumentError('ملاحظة الاعتماد مطلوبة.');

    final actor = await _requireManager();
    final row = await _requireCompanyRow(
      tableId: AppConstants.leaveRequestsTable,
      rowId: leaveId,
      companyId: actor.companyId,
    );
    final leave = LeaveModel.fromMap(_data(row));
    if (!leave.isPending) {
      throw StateError('تم اتخاذ قرار على طلب الإجازة مسبقًا.');
    }
    if (leave.endDate.isBefore(leave.startDate)) {
      throw StateError('نطاق الإجازة غير صالح.');
    }

    final effectivePaid = leave.leaveType.trim() == 'بدون راتب' ? false : isPaid;
    await _ensureNoApprovedLeaveOverlap(leave);

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      rowId: leave.id,
      data: {
        'status': 'approved',
        'is_paid': effectivePaid,
        'review_note': note,
        'reviewed_by': actor.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      },
    );

    try {
      await _reconcileEmployeeRange(
        companyId: actor.companyId,
        employeeId: leave.employeeId,
        start: leave.startDate,
        end: leave.endDate,
        actorId: actor.id,
      );
    } catch (_) {
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.leaveRequestsTable,
        rowId: leave.id,
        data: {
          'status': 'pending',
          'is_paid': null,
          'review_note': null,
          'reviewed_by': null,
          'reviewed_at': null,
        },
      );
      rethrow;
    }

    await _notifications.createNotification(
      companyId: actor.companyId,
      employeeId: leave.employeeId,
      title: 'تم قبول طلب الإجازة',
      body:
          'تم اعتماد طلب الإجازة كإجازة ${effectivePaid ? 'مدفوعة' : 'بدون راتب'}. ملاحظة الإدارة: $note',
      type: 'leave',
      referenceTable: AppConstants.leaveRequestsTable,
      referenceId: leave.id,
    );
  }

  Future<void> rejectLeave({
    required String leaveId,
    required String reviewNote,
  }) async {
    final note = reviewNote.trim();
    if (note.isEmpty) throw ArgumentError('سبب الرفض مطلوب.');

    final actor = await _requireManager();
    final row = await _requireCompanyRow(
      tableId: AppConstants.leaveRequestsTable,
      rowId: leaveId,
      companyId: actor.companyId,
    );
    final leave = LeaveModel.fromMap(_data(row));
    if (!leave.isPending) {
      throw StateError('تم اتخاذ قرار على طلب الإجازة مسبقًا.');
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      rowId: leave.id,
      data: {
        'status': 'rejected',
        'is_paid': null,
        'review_note': note,
        'reviewed_by': actor.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      },
    );

    await _notifications.createNotification(
      companyId: actor.companyId,
      employeeId: leave.employeeId,
      title: 'تم رفض طلب الإجازة',
      body: 'تم رفض طلب الإجازة. ملاحظة الإدارة: $note',
      type: 'leave',
      referenceTable: AppConstants.leaveRequestsTable,
      referenceId: leave.id,
    );
  }

  Future<void> _ensureNoApprovedLeaveOverlap(LeaveModel leave) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('company_id', leave.companyId),
        Query.equal('employee_id', leave.employeeId),
        Query.equal('status', 'approved'),
        Query.limit(500),
      ],
    );
    for (final row in response.rows) {
      if (row.$id == leave.id) continue;
      final other = LeaveModel.fromMap(_data(row));
      final overlaps =
          !leave.endDate.isBefore(other.startDate) &&
          !leave.startDate.isAfter(other.endDate);
      if (overlaps) {
        throw StateError('توجد إجازة معتمدة أخرى متداخلة مع هذه الفترة.');
      }
    }
  }

  Future<List<FactoryStoppageModel>> getFactoryStoppages() async {
    final actor = await _requireManager();
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.factoryStoppagesTable,
      queries: [
        Query.equal('company_id', actor.companyId),
        Query.orderDesc('start_date'),
        Query.limit(500),
      ],
    );
    return response.rows
        .map((row) => FactoryStoppageModel.fromMap(_data(row)))
        .toList();
  }

  Future<void> createFactoryStoppage({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required bool isPaid,
    String? reason,
  }) async {
    final actor = await _requireManager();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('عنوان التوقف مطلوب.');
    final start = _day(startDate);
    final end = _day(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError('تاريخ نهاية التوقف يجب ألا يسبق تاريخ البداية.');
    }
    await _ensureNoStoppageOverlap(actor.companyId, start, end);

    final stoppageId = ID.unique();
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.factoryStoppagesTable,
      rowId: stoppageId,
      data: {
        'company_id': actor.companyId,
        'title': cleanTitle,
        'reason': reason?.trim() ?? '',
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'is_paid': isPaid,
        'created_by': actor.id,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.team(actor.companyId)),
        Permission.update(Role.team(actor.companyId, AppRoles.hrAdmin)),
        Permission.delete(Role.team(actor.companyId, AppRoles.hrAdmin)),
        Permission.update(Role.team(actor.companyId, AppRoles.generalManager)),
        Permission.delete(Role.team(actor.companyId, AppRoles.generalManager)),
      ],
    );

    try {
      await _reconcileCompanyRange(
        companyId: actor.companyId,
        start: start,
        end: end,
        actorId: actor.id,
      );
    } catch (_) {
      await AppwriteService.tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.factoryStoppagesTable,
        rowId: stoppageId,
      );
      rethrow;
    }
  }

  Future<void> deleteFactoryStoppage(String stoppageId) async {
    final actor = await _requireManager();
    final row = await _requireCompanyRow(
      tableId: AppConstants.factoryStoppagesTable,
      rowId: stoppageId,
      companyId: actor.companyId,
    );
    final stoppage = FactoryStoppageModel.fromMap(_data(row));

    await AppwriteService.tablesDB.deleteRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.factoryStoppagesTable,
      rowId: stoppageId,
    );
    await _reconcileCompanyRange(
      companyId: actor.companyId,
      start: stoppage.startDate,
      end: stoppage.endDate,
      actorId: actor.id,
    );
  }

  Future<void> _ensureNoStoppageOverlap(
    String companyId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.factoryStoppagesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.limit(500),
      ],
    );
    for (final row in response.rows) {
      final stoppage = FactoryStoppageModel.fromMap(_data(row));
      final overlaps =
          !end.isBefore(_day(stoppage.startDate)) &&
          !start.isAfter(_day(stoppage.endDate));
      if (overlaps) {
        throw StateError('توجد فترة توقف مصنع متداخلة مع الفترة المحددة.');
      }
    }
  }

  Future<void> _reconcileEmployeeRange({
    required String companyId,
    required String employeeId,
    required DateTime start,
    required DateTime end,
    required String actorId,
  }) async {
    final schedules = await _listScheduleRows(
      companyId: companyId,
      start: start,
      end: end,
      employeeId: employeeId,
    );
    for (final schedule in schedules) {
      await _reconcileScheduleRow(
        companyId: companyId,
        schedule: schedule,
        actorId: actorId,
      );
    }
  }

  Future<void> _reconcileCompanyRange({
    required String companyId,
    required DateTime start,
    required DateTime end,
    required String actorId,
  }) async {
    final schedules = await _listScheduleRows(
      companyId: companyId,
      start: start,
      end: end,
    );
    for (final schedule in schedules) {
      await _reconcileScheduleRow(
        companyId: companyId,
        schedule: schedule,
        actorId: actorId,
      );
    }
  }

  Future<List<models.Row>> _listScheduleRows({
    required String companyId,
    required DateTime start,
    required DateTime end,
    String? employeeId,
  }) async {
    final rows = <models.Row>[];
    var offset = 0;
    const pageSize = 500;
    while (true) {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeWorkSchedulesTable,
        queries: [
          Query.equal('company_id', companyId),
          if (employeeId != null) Query.equal('employee_id', employeeId),
          Query.greaterThanEqual('work_date', _dateKey(start)),
          Query.lessThanEqual('work_date', _dateKey(end)),
          Query.limit(pageSize),
          Query.offset(offset),
        ],
      );
      rows.addAll(response.rows);
      if (response.rows.length < pageSize) break;
      offset += pageSize;
    }
    return rows;
  }

  Future<void> _reconcileScheduleRow({
    required String companyId,
    required models.Row schedule,
    required String actorId,
  }) async {
    final employeeId = schedule.data['employee_id']?.toString() ?? '';
    final workDate = DateTime.parse(schedule.data['work_date'].toString());
    if (employeeId.isEmpty) return;

    final isWorking = schedule.data['is_working_day'] as bool? ?? true;
    final attendance = await _attendanceForDate(
      companyId: companyId,
      employeeId: employeeId,
      workDate: workDate,
    );

    if (!isWorking) {
      await _clearCalendarException(attendance);
      return;
    }

    final effective = await _effectiveExceptionForDate(
      companyId: companyId,
      employeeId: employeeId,
      workDate: workDate,
    );
    if (effective == null) {
      await _clearCalendarException(attendance);
      return;
    }

    final metadata = {
      'calendar_exception_type': effective.type,
      'calendar_exception_ref_id': effective.referenceId,
      'calendar_exception_applied_by': actorId,
      'calendar_exception_applied_at': DateTime.now().toIso8601String(),
    };

    if (attendance != null) {
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendanceTable,
        rowId: attendance.$id,
        data: metadata,
      );
      return;
    }

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      rowId: ID.unique(),
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'work_date': _day(workDate).toIso8601String(),
        'scheduled_start': schedule.data['scheduled_start'],
        'scheduled_end': schedule.data['scheduled_end'],
        'check_in': null,
        'check_out': null,
        'late_minutes': 0,
        'early_leave_minutes': 0,
        'worked_minutes': 0,
        'credited_minutes': 0,
        'overtime_minutes': 0,
        'status': effective.type,
        'attendance_issue_type': '',
        'review_status': 'resolved',
        'review_note': '',
        'source': 'calendar_exception',
        ...metadata,
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.read(Role.team(companyId, AppRoles.hrAdmin)),
        Permission.update(Role.team(companyId, AppRoles.hrAdmin)),
        Permission.delete(Role.team(companyId, AppRoles.hrAdmin)),
        Permission.read(Role.team(companyId, AppRoles.generalManager)),
        Permission.update(Role.team(companyId, AppRoles.generalManager)),
        Permission.read(Role.team(companyId, AppRoles.financialManager)),
      ],
    );
  }

  Future<models.Row?> _attendanceForDate({
    required String companyId,
    required String employeeId,
    required DateTime workDate,
  }) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('employee_id', employeeId),
        Query.equal('work_date', _dateKey(workDate)),
        Query.limit(2),
      ],
    );
    if (response.rows.isEmpty) return null;
    return response.rows.first;
  }

  Future<void> _clearCalendarException(models.Row? attendance) async {
    if (attendance == null) return;
    final source = attendance.data['source']?.toString() ?? '';
    final ref = attendance.data['calendar_exception_ref_id']?.toString() ?? '';
    if (ref.isEmpty) return;

    if (source == 'calendar_exception') {
      await AppwriteService.tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendanceTable,
        rowId: attendance.$id,
      );
      return;
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      rowId: attendance.$id,
      data: {
        'calendar_exception_type': null,
        'calendar_exception_ref_id': null,
        'calendar_exception_applied_by': null,
        'calendar_exception_applied_at': null,
      },
    );
  }

  Future<_CalendarException?> _effectiveExceptionForDate({
    required String companyId,
    required String employeeId,
    required DateTime workDate,
  }) async {
    final stoppages = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.factoryStoppagesTable,
      queries: [Query.equal('company_id', companyId), Query.limit(500)],
    );
    for (final row in stoppages.rows) {
      final item = FactoryStoppageModel.fromMap(_data(row));
      if (_covers(item.startDate, item.endDate, workDate)) {
        return _CalendarException(
          type: item.isPaid
              ? 'factory_stoppage_paid'
              : 'factory_stoppage_unpaid',
          referenceId: item.id,
        );
      }
    }

    final leaves = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('employee_id', employeeId),
        Query.equal('status', 'approved'),
        Query.limit(500),
      ],
    );
    for (final row in leaves.rows) {
      final item = LeaveModel.fromMap(_data(row));
      if (_covers(item.startDate, item.endDate, workDate)) {
        return _CalendarException(
          type: item.isPaid == false ? 'unpaid_leave' : 'paid_leave',
          referenceId: item.id,
        );
      }
    }
    return null;
  }
}

class _CalendarException {
  final String type;
  final String referenceId;

  const _CalendarException({required this.type, required this.referenceId});
}
