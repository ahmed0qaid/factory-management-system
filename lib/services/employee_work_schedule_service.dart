import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../config/constants.dart';
import '../models/employee_work_schedule_model.dart';
import '../models/employee_shift_assignment_model.dart';
import '../models/shift_model.dart';
import 'appwrite_service.dart';

class EmployeeWorkScheduleService {
  // Future use: Update a single daily schedule manually
  Future<void> updateDailySchedule(EmployeeWorkScheduleModel schedule) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeWorkSchedulesTable,
      rowId: schedule.id,
      data: schedule.toMap()
        ..remove('id')
        ..remove('company_id')
        ..remove('employee_id'),
    );
  }

  // Fetch month schedules for a given employee
  Future<Map<String, EmployeeWorkScheduleModel>> getMonthSchedules(
    String companyId,
    String employeeId,
    int year,
    int month,
  ) async {
    final startStr = DateTime(year, month, 1).toIso8601String();
    final endStr = DateTime(year, month + 1, 1).toIso8601String();

    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeWorkSchedulesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual('work_date', startStr),
        Query.lessThan('work_date', endStr),
        Query.limit(100),
      ],
    );

    final map = <String, EmployeeWorkScheduleModel>{};
    for (var r in response.rows) {
      final m = EmployeeWorkScheduleModel.fromMap(r.data, id: r.$id);
      final dateOnly =
          '${m.workDate.year}-${m.workDate.month.toString().padLeft(2, '0')}-${m.workDate.day.toString().padLeft(2, '0')}';
      map[dateOnly] = m;
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
    final existingSchedules = await getMonthSchedules(
      companyId,
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
      } catch (_) {}
    }

    final shiftMap = {for (var s in allShifts) s.id: s};

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(year, month, day);
      final dateOnly =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

      bool isRestDay = restDays.contains(currentDate.weekday);
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

      ShiftModel? shift;
      if (targetShiftId != null) {
        shift = shiftMap[targetShiftId];
      }

      DateTime? scheduledStart;
      DateTime? scheduledEnd;
      String? notes;

      if (isRestDay) {
        notes = 'يوم راحة';
      } else if (shift == null) {
        notes = 'لا يوجد وردية معينة';
      } else {
        final startParts = shift.startTime.split(':');
        final endParts = shift.endTime.split(':');
        final startH = int.parse(startParts[0]);
        final startM = int.parse(startParts[1]);
        final endH = int.parse(endParts[0]);
        final endM = int.parse(endParts[1]);

        scheduledStart = DateTime(year, month, day, startH, startM);

        if (shift.isOvernight) {
          scheduledEnd = DateTime(year, month, day + 1, endH, endM);
        } else {
          scheduledEnd = DateTime(year, month, day, endH, endM);
        }
      }

      final scheduleData = EmployeeWorkScheduleModel(
        id: existingSchedules[dateOnly]?.id ?? '',
        companyId: companyId,
        employeeId: employeeId,
        workDate: DateTime(year, month, day),
        shiftId: shift?.id,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        isWorkingDay: !isRestDay,
        notes: notes,
      );

      if (existingSchedules.containsKey(dateOnly)) {
        await AppwriteService.tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeWorkSchedulesTable,
          rowId: scheduleData.id,
          data: scheduleData.toMap()
            ..remove('id')
            ..remove('company_id')
            ..remove('employee_id'),
        );
      } else {
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeWorkSchedulesTable,
          rowId: ID.unique(),
          data: scheduleData.toMap()..remove('id'),
        );
      }
    }
  }
}
