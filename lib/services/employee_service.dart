import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import '../models/advance_model.dart';
import '../models/announcement_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_policy_model.dart';
import '../models/payroll_model.dart';
import '../models/overtime_record_model.dart';
import '../models/penalty_model.dart';
import '../models/profile_model.dart';
import 'appwrite_service.dart';
import 'auth_service.dart';
import 'payroll_period_service.dart';
import 'salary_calculation_service.dart';

class EmployeeService {
  Future<String> get _uid async => (await AppwriteService.account.get()).$id;

  Map<String, dynamic> _data(models.Row row) => {...row.data, 'id': row.$id};

  Future<ProfileModel> getMyProfile() async {
    final user = await AppwriteService.account.get();
    final uid = user.$id;

    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: uid,
    );
    return ProfileModel.fromMap(_data(row));
  }

  Future<List<AttendanceRecordModel>> getMyAttendance({int limit = 31}) async {
    final uid = await _uid;
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.orderDesc('work_date'),
        Query.limit(limit),
      ],
    );
    return data.rows
        .map((e) => AttendanceRecordModel.fromMap(_data(e)))
        .toList();
  }

  Future<AttendanceRecordModel?> getTodayAttendance() async {
    final uid = await _uid;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.equal('work_date', today),
        Query.limit(1),
      ],
    );
    if (data.rows.isEmpty) return null;
    return AttendanceRecordModel.fromMap(_data(data.rows.first));
  }

  Future<List<PenaltyModel>> getMyPenalties({int limit = 50}) async {
    final uid = await _uid;
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.orderDesc('penalty_date'),
        Query.limit(limit),
      ],
    );
    return data.rows.map((e) => PenaltyModel.fromMap(_data(e))).toList();
  }

  Future<List<PayrollRecordModel>> getMyPayroll({int limit = 12}) async {
    final uid = await _uid;
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.orderDesc('created_at'),
        Query.limit(limit),
      ],
    );
    return data.rows.map((e) => PayrollRecordModel.fromMap(_data(e))).toList();
  }

  Future<List<AdvanceModel>> getMyAdvances({int limit = 50}) async {
    final uid = await _uid;
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.orderDesc('created_at'),
        Query.limit(limit),
      ],
    );
    return data.rows.map((e) => AdvanceModel.fromMap(_data(e))).toList();
  }

  Future<List<AnnouncementModel>> getAnnouncements({int limit = 10}) async {
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      queries: [Query.orderDesc('publish_at'), Query.limit(limit)],
    );
    return data.rows.map((e) => AnnouncementModel.fromMap(_data(e))).toList();
  }

  Future<MonthlySalaryReport> getSalaryReportForMonth({
    required int year,
    required int month,
  }) async {
    final profile = await getMyProfile();
    final uid = await _uid;

    final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);

    // Get attendance for current month
    final attendanceData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual('work_date', start),
        Query.lessThanEqual('work_date', end),
        Query.limit(500),
      ],
    );
    final attendance = attendanceData.rows
        .map((e) => AttendanceRecordModel.fromMap(_data(e)))
        .toList();

    // Get penalties for current month
    final penaltiesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual('penalty_date', start),
        Query.lessThanEqual('penalty_date', end),
        Query.limit(500),
      ],
    );
    final penalties = penaltiesData.rows
        .map((e) => PenaltyModel.fromMap(_data(e)))
        .where((p) => p.status == 'pending' || p.status == 'approved')
        .toList();

    // Get advances for current month
    final advancesStart = DateTime(year, month, 1).toIso8601String();
    final advancesEnd = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
    final advancesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual('created_at', advancesStart),
        Query.lessThanEqual('created_at', advancesEnd),
        Query.limit(500),
      ],
    );
    num advancesTotal = 0;
    for (var doc in advancesData.rows) {
      final status = doc.data['status']?.toString() ?? '';
      if (status == 'approved' || status == 'paid') {
        advancesTotal += (doc.data['principal_amount'] as num? ?? 0);
      }
    }

    return SalaryCalculationService.calculateMonthlySalaryReport(
      employee: profile,
      attendanceRecords: attendance,
      penalties: penalties,
      advancesTotal: advancesTotal,
      year: year,
      month: month,
      fridayMode: FridaySalaryMode.includeFridays, // Default for employee view if not saved per employee
    );
  }

  Future<AdvanceBalanceInfo> getAdvanceBalance() async {
    final profile = await getMyProfile();
    final uid = await _uid;
    final now = DateTime.now();
    final period = PayrollPeriodService.getCurrentPayrollPeriod(now);

    // Count working days in period (excluding Fridays)
    final workingDaysInPeriod = PayrollPeriodService.countWorkingDays(
      period.periodStart,
      period.periodEnd,
    );

    // Count working days until today (excluding Fridays)
    final workingDaysUntilToday = PayrollPeriodService.countWorkingDays(
      period.periodStart,
      now,
    );

    // Get attendance in this period
    final attendanceData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual(
          'work_date',
          period.periodStart.toIso8601String().substring(0, 10),
        ),
        Query.lessThanEqual(
          'work_date',
          period.periodEnd.toIso8601String().substring(0, 10),
        ),
      ],
    );

    int attendanceDays = 0;
    for (var doc in attendanceData.rows) {
      final status = doc.data['status'];
      if (status == 'present' || status == 'late') {
        attendanceDays++;
      } else if (doc.data['check_in'] != null) {
        // Fallback if status is incomplete but check_in exists
        attendanceDays++;
      }
    }

    // Calculate accrued salary
    final monthlyEntitlement = profile.baseSalary + profile.monthlyBonus;
    final accruedSalary = workingDaysInPeriod > 0
        ? (monthlyEntitlement * attendanceDays / workingDaysInPeriod)
        : 0;

    // Get previous advances in this period
    final advancesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual(
          'created_at',
          period.periodStart.toIso8601String(),
        ),
        Query.lessThanEqual('created_at', period.periodEnd.toIso8601String()),
      ],
    );

    num previousAdvances = 0;
    for (var doc in advancesData.rows) {
      final status = doc.data['status'];
      if (status == 'pending' || status == 'approved' || status == 'paid') {
        previousAdvances += (doc.data['principal_amount'] as num? ?? 0);
      }
    }

    // Get penalties in this period
    final penaltiesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual(
          'penalty_date',
          period.periodStart.toIso8601String().substring(0, 10),
        ),
        Query.lessThanEqual(
          'penalty_date',
          period.periodEnd.toIso8601String().substring(0, 10),
        ),
      ],
    );

    int penaltiesCount = 0;
    num penaltiesAmount = 0;
    for (var doc in penaltiesData.rows) {
      final status = doc.data['status'];
      if (status == 'pending' || status == 'approved') {
        penaltiesCount++;
        penaltiesAmount += (doc.data['amount'] as num? ?? 0);
      }
    }

    final availableBalance = accruedSalary - previousAdvances - penaltiesAmount;

    return AdvanceBalanceInfo(
      periodStart: period.periodStart,
      periodEnd: period.periodEnd,
      workingDaysInPeriod: workingDaysInPeriod,
      workingDaysUntilToday: workingDaysUntilToday,
      attendanceDays: attendanceDays,
      monthlyEntitlement: monthlyEntitlement,
      accruedSalary: accruedSalary,
      previousAdvances: previousAdvances,
      penaltiesCount: penaltiesCount,
      penaltiesAmount: penaltiesAmount,
      availableBalance: availableBalance,
      canRequestAdvance: availableBalance > 0,
    );
  }

  Future<void> requestAdvance({
    required num amount,
    required String reason,
  }) async {
    final balanceInfo = await getAdvanceBalance();
    if (balanceInfo.availableBalance <= 0) {
      throw Exception('لا يوجد رصيد متاح للسلفة حاليًا.');
    }
    if (amount > balanceInfo.availableBalance) {
      throw Exception('لا يمكنك طلب مبلغ أكبر من الرصيد المتاح.');
    }

    final profile = await getMyProfile();
    final uid = await _uid;
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      rowId: ID.unique(),
      data: {
        'company_id': profile.companyId,
        'employee_id': uid,
        'principal_amount': amount,
        'installment_amount':
            0, // No longer used, but kept for schema compatibility
        'remaining_amount': amount,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(uid)),
        Permission.update(Role.user(uid)),
        Permission.read(Role.team('company_main')),
      ],
    );
  }

  Future<List<models.Row>> getMyLeaves({int limit = 50}) async {
    final uid = await _uid;
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.orderDesc('created_at'),
        Query.limit(limit),
      ],
    );
    return data.rows;
  }

  Future<void> requestLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final profile = await getMyProfile();
    final uid = await _uid;
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      rowId: ID.unique(),
      data: {
        'company_id': profile.companyId,
        'employee_id': uid,
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(uid)),
        Permission.update(Role.user(uid)),
        Permission.read(Role.team('company_main')),
      ],
    );
  }

  Future<int> getLeaveRequestsCount() async {
    final uid = await _uid;
    final now = DateTime.now();
    final period = PayrollPeriodService.getCurrentPayrollPeriod(now);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.greaterThanEqual(
          'start_date',
          period.periodStart.toIso8601String().substring(0, 10),
        ),
        Query.lessThanEqual(
          'start_date',
          period.periodEnd.toIso8601String().substring(0, 10),
        ),
      ],
    );
    return data.total;
  }

  Future<List<Map<String, dynamic>>> getFactoryStoppages() async {
    final profile = await getMyProfile();
    final now = DateTime.now();
    final period = PayrollPeriodService.getCurrentPayrollPeriod(now);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.factoryStoppagesTable,
      queries: [
        Query.equal('company_id', profile.companyId),
        Query.greaterThanEqual(
          'start_date',
          period.periodStart.toIso8601String(),
        ),
        Query.lessThanEqual('start_date', period.periodEnd.toIso8601String()),
        Query.orderDesc('start_date'),
      ],
    );
    return data.rows.map((e) => e.data).toList();
  }

  // --- Attendance Policy & Alerts ---
  Future<List<AttendanceRecordModel>> getAttendanceAlerts() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return [];

    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', user.$id),
        Query.equal('status', 'needs_review'),
      ],
    );

    return docs.rows
        .map((doc) => AttendanceRecordModel.fromMap(_data(doc)))
        .toList();
  }

  Future<AttendancePolicyModel?> getActiveAttendancePolicy() async {
    try {
      final docs = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendancePoliciesTable,
        queries: [
          Query.equal('company_id', 'company_main'),
          Query.equal('active', true),
        ],
      );

      if (docs.rows.isEmpty) return null;

      return AttendancePolicyModel.fromMap(
        docs.rows.first.data,
        id: docs.rows.first.$id,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<OvertimeRecordModel>> getMyOvertime({int limit = 31}) async {
    final uid = await _uid;
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: [
        Query.equal('employee_id', uid),
        Query.orderDesc('work_date'),
        Query.limit(limit),
      ],
    );
    return data.rows.map((e) => OvertimeRecordModel.fromMap(_data(e))).toList();
  }
}
