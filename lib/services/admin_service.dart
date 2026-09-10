import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import '../models/profile_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_policy_model.dart';
import '../models/advance_model.dart';
import '../models/penalty_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'payroll_period_service.dart';

class AdminService {
  Map<String, dynamic> _data(models.Row row) => {...row.data, 'id': row.$id};

  Future<List<ProfileModel>> getEmployees({int limit = 100}) async {
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      queries: [Query.orderDesc(r'$createdAt'), Query.limit(limit)],
    );
    return data.rows.map((e) => ProfileModel.fromMap(_data(e))).toList();
  }

  Future<List<AttendanceRecordModel>> getEmployeeAttendanceForMonth({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual('work_date', start),
        Query.lessThanEqual('work_date', end),
        Query.limit(500),
      ],
    );
    return data.rows
        .map((e) => AttendanceRecordModel.fromMap(_data(e)))
        .toList();
  }

  Future<List<PenaltyModel>> getEmployeePenaltiesForMonth({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual('penalty_date', start),
        Query.lessThanEqual('penalty_date', end),
        Query.limit(500),
      ],
    );
    return data.rows
        .map((e) => PenaltyModel.fromMap(_data(e)))
        .where((p) => p.status == 'pending' || p.status == 'approved')
        .toList();
  }

  Future<num> getEmployeeAdvancesForMonth({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual('created_at', start),
        Query.lessThanEqual('created_at', end),
        Query.limit(500),
      ],
    );
    num total = 0;
    for (final row in data.rows) {
      final status = row.data['status']?.toString() ?? '';
      if (status == 'approved' || status == 'paid') {
        total += (row.data['principal_amount'] as num? ?? 0);
      }
    }
    return total;
  }

  Future<List<models.Row>> getPayrollRows({int limit = 500}) async {
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollTable,
      queries: [Query.orderDesc('created_at'), Query.limit(limit)],
    );
    return data.rows;
  }

  Future<List<models.Row>> getAttendanceRows({int limit = 1000}) async {
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [Query.orderDesc('work_date'), Query.limit(limit)],
    );
    return data.rows;
  }

  Future<void> createEmployee({
    required String employeeNumber,
    required String fullName,
    required String temporaryPassword,
    required String role,
    String? phone,
    String? departmentName,
    String? jobTitleId,
    String? jobTitleName,
    num baseSalary = 0,
    num monthlyBonus = 0,
    String? biometricEmployeeId,
  }) async {
    if (!AppRoles.assignableRoles.contains(role)) {
      throw Exception('دور غير مسموح');
    }

    final payload = {
      'employeeNumber': employeeNumber,
      'fullName': fullName,
      'temporaryPassword': temporaryPassword,
      'role': role,
      'baseSalary': baseSalary,
      'monthlyBonus': monthlyBonus,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (biometricEmployeeId != null && biometricEmployeeId.trim().isNotEmpty)
        'biometricEmployeeId': biometricEmployeeId.trim(),
      if (departmentName != null && departmentName.trim().isNotEmpty)
        'departmentName': departmentName.trim(),
      if (jobTitleId != null && jobTitleId.trim().isNotEmpty)
        'jobTitleId': jobTitleId.trim(),
      if (jobTitleName != null && jobTitleName.trim().isNotEmpty)
        'jobTitleName': jobTitleName.trim(),
    };

    final execution = await AppwriteService.functions.createExecution(
      functionId: AppConstants.createEmployeeFunctionId,
      body: jsonEncode(payload),
      xasync: false,
    );

    if (execution.status.name.toLowerCase() != 'completed') {
      throw Exception(
        execution.errors.isNotEmpty
            ? execution.errors
            : 'فشل تنفيذ دالة إنشاء الموظف',
      );
    }

    final response = jsonDecode(
      execution.responseBody.isEmpty ? '{}' : execution.responseBody,
    );
    if (response is Map && response['success'] != true) {
      throw Exception(response['error'] ?? 'فشل إنشاء الموظف');
    }
  }

  Future<void> addPenalty({
    required String companyId,
    required String employeeId,
    required String category,
    required String reason,
    required num amount,
    required int minutesDeducted,
    required String penaltyDate,
  }) async {
    final penaltyId = ID.unique();
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      rowId: penaltyId,
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'category': category,
        'reason': reason,
        'amount': amount,
        'minutes_deducted': minutesDeducted,
        'penalty_date': penaltyDate,
        'status': 'approved',
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
        Permission.update(Role.team('company_main', 'hr_admin')),
      ],
    );

    // Notify employee
    final db = AppwriteService.tablesDB;
    await db.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'title': 'تم إضافة جزاء',
        'body':
            'تم إضافة جزاء جديد على حسابك، يمكنك مراجعة التفاصيل من واجهة الجزاءات.',
        'type': 'penalty',
        'reference_table': AppConstants.penaltiesTable,
        'reference_id': penaltyId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.update(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
      ],
    );
  }

  Future<void> addPayroll({
    required String companyId,
    required String employeeId,
    required num baseSalary,
    required num monthlyBonus,
    required num overtimeAmount,
    required num allowances,
    required num bonuses,
    required num absenceDeductions,
    required num lateDeductions,
    required num penaltiesAmount,
    required num advanceInstallments,
    required num otherDeductions,
  }) async {
    final monthlyEntitlement = baseSalary + monthlyBonus;
    final netSalary =
        monthlyEntitlement +
        overtimeAmount +
        allowances +
        bonuses -
        absenceDeductions -
        lateDeductions -
        penaltiesAmount -
        advanceInstallments -
        otherDeductions;

    final payrollId = ID.unique();
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollTable,
      rowId: payrollId,
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'base_salary': baseSalary,
        'monthly_bonus': monthlyBonus,
        'monthly_entitlement': monthlyEntitlement,
        'overtime_amount': overtimeAmount,
        'allowances': allowances,
        'bonuses': bonuses,
        'absence_deductions': absenceDeductions,
        'late_deductions': lateDeductions,
        'penalties_amount': penaltiesAmount,
        'advance_installments': advanceInstallments,
        'other_deductions': otherDeductions,
        'net_salary': netSalary,
        'status': 'approved',
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
        Permission.update(Role.team('company_main', 'hr_admin')),
      ],
    );

    // Notify employee
    final db = AppwriteService.tablesDB;
    await db.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'title': 'تم اعتماد الراتب',
        'body':
            'تم اعتماد راتبك لهذا الشهر، يمكنك مراجعة كشف الراتب من واجهة الراتب.',
        'type': 'payroll',
        'reference_table': AppConstants.payrollTable,
        'reference_id': payrollId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.update(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
      ],
    );
  }

  Future<List<models.Row>> getPendingAdvances() async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('status', 'pending'),
        Query.orderDesc('created_at'),
      ],
    );
    return response.rows;
  }

  Future<AdvanceBalanceInfo> getEmployeeAdvanceBalance(
    String employeeId,
  ) async {
    final now = DateTime.now();
    final period = PayrollPeriodService.getCurrentPayrollPeriod(now);

    // Get profile
    final profileRow = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: employeeId,
    );
    final profile = ProfileModel.fromMap(_data(profileRow));

    final workingDaysInPeriod = PayrollPeriodService.countWorkingDays(
      period.periodStart,
      period.periodEnd,
    );

    // Get attendance
    final attendanceData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('employee_id', employeeId),
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
        attendanceDays++;
      }
    }

    final monthlyEntitlement = profile.baseSalary + profile.monthlyBonus;
    final accruedSalary = workingDaysInPeriod > 0
        ? (monthlyEntitlement * attendanceDays / workingDaysInPeriod)
        : 0;

    final advancesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('employee_id', employeeId),
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

    final penaltiesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('employee_id', employeeId),
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

    final workingDaysUntilToday = PayrollPeriodService.countWorkingDays(
      period.periodStart,
      now,
    );
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

  Future<void> updateAdvanceStatus({
    required String advanceId,
    required String companyId,
    required String employeeId,
    required String status,
  }) async {
    if (status == 'approved') {
      // Re-check balance before approving
      final balanceInfo = await getEmployeeAdvanceBalance(employeeId);

      // Get the requested advance amount

      // Notice: previousAdvances already includes 'pending' advances.
      // If this advance is 'pending', its amount is already subtracted from availableBalance.
      // So if availableBalance < 0, it means including this advance, they are over limit.
      if (balanceInfo.availableBalance < 0) {
        throw Exception(
          'لا يمكن اعتماد السلفة لأن رصيد الموظف المتاح غير كافٍ.',
        );
      }
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      rowId: advanceId,
      data: {'status': status},
    );

    // Notify employee
    final db = AppwriteService.tablesDB;
    await db.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'title': status == 'approved'
            ? 'تم اعتماد طلب السلفة'
            : 'تم رفض طلب السلفة',
        'body': status == 'approved'
            ? 'تم اعتماد طلب السلفة وسيتم خصمها من راتب الفترة الحالية.'
            : 'تم رفض طلب السلفة الخاص بك.',
        'type': 'advance',
        'reference_table': AppConstants.advancesTable,
        'reference_id': advanceId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.update(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
      ],
    );
  }

  Future<List<models.Row>> getPendingLeaves() async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('status', 'pending'),
        Query.orderDesc('created_at'),
      ],
    );
    return response.rows;
  }

  Future<void> updateLeaveStatus({
    required String leaveId,
    required String companyId,
    required String employeeId,
    required String status,
  }) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      rowId: leaveId,
      data: {'status': status, 'reviewed_at': DateTime.now().toIso8601String()},
    );

    // Notify employee
    final db = AppwriteService.tablesDB;
    await db.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': companyId,
        'employee_id': employeeId,
        'title': status == 'approved'
            ? 'تم اعتماد طلب الإجازة'
            : 'تم رفض طلب الإجازة',
        'body': status == 'approved'
            ? 'تم اعتماد طلب الإجازة الخاص بك.'
            : 'تم رفض طلب الإجازة الخاص بك.',
        'type': 'leave',
        'reference_table': AppConstants.leaveRequestsTable,
        'reference_id': leaveId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [
        Permission.read(Role.user(employeeId)),
        Permission.update(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
      ],
    );
  }

  // --- Attendance Policy ---
  Future<AttendancePolicyModel> getActiveAttendancePolicy(
    String companyId,
  ) async {
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendancePoliciesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('active', true),
      ],
    );

    if (docs.rows.isEmpty) {
      throw Exception('لا توجد سياسة دوام نشطة.');
    }

    return AttendancePolicyModel.fromMap(
      docs.rows.first.data,
      id: docs.rows.first.$id,
    );
  }

  Future<void> updateAttendancePolicy(AttendancePolicyModel policy) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendancePoliciesTable,
      rowId: policy.id,
      data: {
        'grace_late_minutes': policy.graceLateMinutes,
        'grace_early_leave_minutes': policy.graceEarlyLeaveMinutes,
        'late_calculation_mode': policy.lateCalculationMode,
        'early_leave_calculation_mode': policy.earlyLeaveCalculationMode,
        'overtime_minimum_minutes': policy.overtimeMinimumMinutes,
        'overtime_requires_hr_approval': policy.overtimeRequiresHrApproval,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> updateEmployeeStatus(String employeeId, bool isActive) async {
    if (!isActive) {
      final doc = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        rowId: employeeId,
      );
      if (doc.data['role'] == AppRoles.hrAdmin) {
        throw Exception('لا يمكن تعطيل حساب الموارد البشرية');
      }
    }
    try {
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        rowId: employeeId,
        data: {'active': isActive},
      );
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        throw Exception(
          'لا توجد صلاحية لتعديل بيانات الموظف. يرجى إصلاح صلاحيات HR Admin في Appwrite.',
        );
      }
      throw Exception(e.message ?? 'خطأ في قاعدة البيانات');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> updateEmployeeData(
    String employeeId, {
    String? fullName,
    String? departmentName,
    String? jobTitleId,
    String? jobTitleName,
    String? biometricEmployeeId,
    String? phone,
    num? baseSalary,
    num? monthlyBonus,
    num? dailyWorkHours,
    bool? active,
  }) async {
    final newBiometricId =
        (biometricEmployeeId == null || biometricEmployeeId.trim().isEmpty)
        ? ''
        : biometricEmployeeId.trim();

    if (newBiometricId.isNotEmpty) {
      final existing = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        queries: [
          Query.equal('biometric_employee_id', newBiometricId),
          Query.limit(5),
        ],
      );
      if (existing.rows.any((r) => r.$id != employeeId)) {
        throw Exception('رقم البصمة مستخدم بالفعل لموظف آخر.');
      }
    }

    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (departmentName != null) data['department_name'] = departmentName;
    if (jobTitleId != null) data['job_title_id'] = jobTitleId;
    if (jobTitleName != null) data['job_title_name'] = jobTitleName;

    // Set to empty string if it was cleared
    data['biometric_employee_id'] = newBiometricId;

    if (phone != null) data['phone'] = phone.trim().isEmpty ? '' : phone.trim();
    if (baseSalary != null) data['base_salary'] = baseSalary;
    if (monthlyBonus != null) data['monthly_bonus'] = monthlyBonus;
    if (dailyWorkHours != null) data['daily_work_hours'] = dailyWorkHours;
    if (active == false) {
      final doc = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        rowId: employeeId,
      );
      if (doc.data['role'] == AppRoles.hrAdmin) {
        throw Exception('لا يمكن تعطيل حساب الموارد البشرية');
      }
    }

    if (active != null) data['active'] = active;

    if (data.isEmpty) return;

    try {
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        rowId: employeeId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        throw Exception(
          'لا توجد صلاحية لتعديل بيانات الموظف. يرجى إصلاح صلاحيات HR Admin في Appwrite.',
        );
      }
      throw Exception(e.message ?? 'خطأ في قاعدة البيانات');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> updateEmployeeBiometricId(
    String employeeId,
    String? biometricId,
  ) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: employeeId,
      data: {'biometric_employee_id': biometricId},
    );
  }

  Future<void> updateEmployeeCredentials({
    required String profileId,
    String? newEmployeeNumber,
    String? newPassword,
    bool? mustChangePassword,
  }) async {
    final payload = {
      'profileId': profileId,
      if (newEmployeeNumber != null && newEmployeeNumber.trim().isNotEmpty)
        'newEmployeeNumber': newEmployeeNumber.trim(),
      if (newPassword != null && newPassword.trim().isNotEmpty)
        'newPassword': newPassword.trim(),
      if (mustChangePassword != null) 'mustChangePassword': mustChangePassword,
    };

    final execution = await AppwriteService.functions.createExecution(
      functionId: AppConstants.updateEmployeeCredentialsFunctionId,
      body: jsonEncode(payload),
      xasync: false,
    );

    if (execution.status.name.toLowerCase() != 'completed') {
      throw Exception(
        execution.errors.isNotEmpty
            ? execution.errors
            : 'فشل تنفيذ دالة التحديث',
      );
    }

    final response = jsonDecode(
      execution.responseBody.isEmpty ? '{}' : execution.responseBody,
    );
    if (response is Map && response['success'] != true) {
      throw Exception(response['error'] ?? 'فشل تحديث بيانات الموظف');
    }
  }
}
