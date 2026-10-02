import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/employee_shift_assignment_model.dart';
import '../models/employee_work_schedule_model.dart';
import '../models/profile_model.dart';
import '../models/shift_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

class EmployeeWorkScheduleService {
  Future<ProfileModel> _requireHrProfile() async {
    final profile = await CompanyContextService.getCurrentProfile();
    if (!AppRoles.canConfigureAttendance(profile.role)) {
      throw StateError('هذه العملية متاحة للموارد البشرية فقط.');
    }
    if (!profile.active) {
      throw StateError('الحساب الإداري غير نشط.');
    }
    return profile;
  }

  Future<ProfileModel> _requireEmployeeInCompany(
    String employeeId,
    String companyId,
  ) async {
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: employeeId,
    );
    final employee = ProfileModel.fromMap({...row.data, 'id': row.$id});
    if (employee.companyId != companyId) {
      throw StateError('الموظف لا يتبع شركة المستخدم الحالية.');
    }
    return employee;
  }

  Future<EmployeeWorkScheduleModel> _requireScheduleRow(
    String scheduleId,
    String companyId,
  ) async {
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeWorkSchedulesTable,
      rowId: scheduleId,
    );
    final schedule = EmployeeWorkScheduleModel.fromMap(row.data, id: row.$id);
    if (schedule.companyId != companyId) {
      throw StateError('سجل الدوام لا يتبع شركة المستخدم الحالية.');
    }
    return schedule;
  }

  Future<void> updateDailySchedule(EmployeeWorkScheduleModel schedule) async {
    final actor = await _requireHrProfile();
    final companyId = actor.companyId;
    await _requireEmployeeInCompany(schedule.employeeId, companyId);
    final persisted = await _requireScheduleRow(schedule.id, companyId);

    if (persisted.employeeId != schedule.employeeId ||
        !_sameDay(persisted.workDate, schedule.workDate)) {
      throw StateError('لا يمكن تغيير الموظف أو تاريخ سجل الدوام اليومي.');
    }

    String? shiftId;
    DateTime? start;
    DateTime? end;
    var notes = schedule.notes?.trim();

    if (schedule.isWorkingDay) {
      shiftId = schedule.shiftId;
      start = schedule.scheduledStart;
      end = schedule.scheduledEnd;
      if (shiftId == null || shiftId.trim().isEmpty) {
        throw ArgumentError('يجب اختيار وردية ليوم العمل.');
      }
      if (start == null || end == null || !end.isAfter(start)) {
        throw ArgumentError('وقت بداية ونهاية الدوام غير صالحين.');
      }
      if (!_sameDay(start, persisted.workDate)) {
        throw ArgumentError('بداية الدوام يجب أن تكون في نفس يوم الجدول.');
      }

      final shiftRow = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.shiftsTable,
        rowId: shiftId,
      );
      if (shiftRow.data['company_id']?.toString() != companyId) {
        throw StateError('الوردية المختارة لا تتبع الشركة الحالية.');
      }
    } else {
      shiftId = null;
      start = null;
      end = null;
      if (notes == null || notes.isEmpty) notes = 'يوم راحة';
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeWorkSchedulesTable,
      rowId: schedule.id,
      data: {
        'shift_id': shiftId,
        'scheduled_start': start?.toIso8601String(),
        'scheduled_end': end?.toIso8601String(),
        'is_working_day': schedule.isWorkingDay,
        'notes': notes,
        'is_manual_override': true,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': actor.id,
      },
    );
  }

  Future<Map<String, EmployeeWorkScheduleModel>> getMonthSchedules(
    String companyId,
    String employeeId,
    int year,
    int month,
  ) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    await _requireEmployeeInCompany(employeeId, scopedCompanyId);
    final startStr = DateTime(year, month, 1).toIso8601String();
    final endStr = DateTime(year, month + 1, 1).toIso8601String();

    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeWorkSchedulesTable,
      queries: [
        Query.equal('company_id', scopedCompanyId),
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual('work_date', startStr),
        Query.lessThan('work_date', endStr),
        Query.orderAsc('work_date'),
        Query.limit(100),
      ],
    );

    final map = <String, EmployeeWorkScheduleModel>{};
    for (final row in response.rows) {
      final schedule = EmployeeWorkScheduleModel.fromMap(
        row.data,
        id: row.$id,
      );
      map[_dateKey(schedule.workDate)] = schedule;
    }
    return map;
  }

  Future<void> generateMonthSchedule({
    required String companyId,
    required String employeeId,
    required int year,
    required int month,
    required EmployeeShiftAssignmentModel assignment,
    required List<ShiftModel> allShifts,
    required List<int> restDays,
  }) async {
    final actor = await _requireHrProfile();
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    if (actor.companyId != scopedCompanyId) {
      throw StateError('لا يمكن توليد جدول لشركة أخرى.');
    }
    final employee = await _requireEmployeeInCompany(
      employeeId,
      scopedCompanyId,
    );
    if (!employee.active || employee.employmentStatus != 'active') {
      throw StateError('لا يمكن توليد جدول جديد لموظف غير نشط.');
    }
    if (assignment.companyId != scopedCompanyId ||
        assignment.employeeId != employeeId ||
        !assignment.active) {
      throw StateError('تعيين الوردية لا يطابق الموظف أو الشركة الحالية.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError('الشهر غير صالح.');
    }

    final existingSchedules = await getMonthSchedules(
      scopedCompanyId,
      employeeId,
      year,
      month,
    );
    final daysInMonth = DateTime(year, month + 1, 0).day;

    String? week1ShiftId;
    String? week2ShiftId;
    if (assignment.assignmentType == 'weekly_rotation' &&
        assignment.rotationPattern != null) {
      try {
        final map = jsonDecode(assignment.rotationPattern!);
        final weeks = map['weeks'] as List;
        if (weeks.isNotEmpty) week1ShiftId = weeks[0]['shift_id'];
        if (weeks.length > 1) week2ShiftId = weeks[1]['shift_id'];
      } catch (_) {
        throw StateError('نمط تدوير الورديات غير صالح.');
      }
    }

    final shiftMap = {
      for (final shift in allShifts)
        if (shift.companyId == scopedCompanyId) shift.id: shift,
    };

    for (var day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(year, month, day);
      final dateOnly = _dateKey(currentDate);
      final existing = existingSchedules[dateOnly];

      // A reviewed manual day is authoritative and must survive regeneration.
      if (existing?.isManualOverride == true) continue;

      final isRestDay = restDays.contains(currentDate.weekday);
      String? targetShiftId;

      if (!isRestDay) {
        if (assignment.assignmentType == 'fixed') {
          targetShiftId = assignment.fixedShiftId;
        } else if (assignment.assignmentType == 'weekly_rotation') {
          if (assignment.rotationStartDate != null) {
            final diffDays = currentDate
                .difference(assignment.rotationStartDate!)
                .inDays;
            if (diffDays >= 0) {
              final weekNum = (diffDays ~/ 7) % 2;
              targetShiftId = weekNum == 0 ? week1ShiftId : week2ShiftId;
            } else {
              targetShiftId = week1ShiftId;
            }
          }
        }
      }

      final shift = targetShiftId == null ? null : shiftMap[targetShiftId];
      DateTime? scheduledStart;
      DateTime? scheduledEnd;
      String? notes;

      if (isRestDay) {
        notes = 'يوم راحة';
      } else if (shift == null) {
        notes = 'لا توجد وردية معينة';
      } else {
        scheduledStart = _atTime(currentDate, shift.startTime);
        final rawEnd = _atTime(currentDate, shift.endTime);
        scheduledEnd = shift.isOvernight || !rawEnd.isAfter(scheduledStart)
            ? rawEnd.add(const Duration(days: 1))
            : rawEnd;
      }

      final scheduleData = EmployeeWorkScheduleModel(
        id: existing?.id ?? '',
        companyId: scopedCompanyId,
        employeeId: employeeId,
        workDate: currentDate,
        shiftId: shift?.id,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        isWorkingDay: !isRestDay,
        notes: notes,
        isManualOverride: false,
        updatedAt: DateTime.now(),
        updatedBy: actor.id,
      );

      if (existing != null) {
        await AppwriteService.tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeWorkSchedulesTable,
          rowId: existing.id,
          data: scheduleData.toMap()
            ..remove('company_id')
            ..remove('employee_id')
            ..remove('work_date'),
        );
      } else {
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeWorkSchedulesTable,
          rowId: ID.unique(),
          data: scheduleData.toMap(),
          permissions: [
            Permission.read(Role.user(employeeId)),
            Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
            Permission.update(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
            Permission.delete(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
            Permission.read(
              Role.team(scopedCompanyId, AppRoles.generalManager),
            ),
          ],
        );
      }
    }
  }

  DateTime _atTime(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) throw ArgumentError('وقت الوردية غير صالح: $hhmm');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
