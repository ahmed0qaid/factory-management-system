import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import '../models/advance_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_policy_model.dart';
import '../models/penalty_model.dart';
import '../models/profile_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';
import 'payroll_period_service.dart';

class AdminService {
  Map<String, dynamic> _data(models.Row row) => {...row.data, 'id': row.$id};

  Future<String> _companyId() => CompanyContextService.getCurrentCompanyId();

  Future<ProfileModel> _requireEmployeeInCurrentCompany(
    String employeeId,
  ) async {
    final companyId = await _companyId();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: employeeId,
    );
    final profile = ProfileModel.fromMap(_data(row));
    if (profile.companyId != companyId) {
      throw StateError('الموظف لا يتبع شركة المستخدم الحالية.');
    }
    return profile;
  }

  Future<models.Row> _requireCompanyRow({
    required String tableId,
    required String rowId,
    required String companyId,
    String? employeeId,
  }) async {
    await CompanyContextService.requireCompany(companyId);
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: tableId,
      rowId: rowId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('السجل لا يتبع شركة المستخدم الحالية.');
    }
    if (employeeId != null &&
        row.data['employee_id']?.toString() != employeeId) {
      throw StateError('السجل لا يتبع الموظف المحدد.');
    }
    return row;
  }

  Future<List<ProfileModel>> getEmployees({int limit = 100}) async {
    final companyId = await _companyId();
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.orderDesc(r'$createdAt'),
        Query.limit(limit),
      ],
    );
    return data.rows.map((e) => ProfileModel.fromMap(_data(e))).toList();
  }

  Future<List<AttendanceRecordModel>> getEmployeeAttendanceForMonth({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final profile = await _requireEmployeeInCurrentCompany(employeeId);
    final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('company_id', profile.companyId),
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
    final profile = await _requireEmployeeInCurrentCompany(employeeId);
    final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('company_id', profile.companyId),
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
    final profile = await _requireEmployeeInCurrentCompany(employeeId);
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('company_id', profile.companyId),
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
    final companyId = await _companyId();
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.orderDesc('created_at'),
        Query.limit(limit),
      ],
    );
    return data.rows;
  }

  Future<List<models.Row>> getAttendanceRows({int limit = 1000}) async {
    final companyId = await _companyId();
    final data = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.orderDesc('work_date'),
        Query.limit(limit),
      ],
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
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    await _requireEmployeeInCurrentCompany(employeeId);
    final penaltyId = ID.unique();
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      rowId: penaltyId,
      data: {
        'company_id': scopedCompanyId,
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
        Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.update(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.read(Role.team(scopedCompanyId, AppRoles.generalManager)),
        Permission.update(Role.team(scopedCompanyId, AppRoles.generalManager)),
      ],
    );

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': scopedCompanyId,
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
        Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
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
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    await _requireEmployeeInCurrentCompany(employeeId);
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
        'company_id': scopedCompanyId,
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
        Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.update(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.read(Role.team(scopedCompanyId, AppRoles.financialManager)),
        Permission.update(
          Role.team(scopedCompanyId, AppRoles.financialManager),
        ),
      ],
    );

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': scopedCompanyId,
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
        Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.read(Role.team(scopedCompanyId, AppRoles.financialManager)),
      ],
    );
  }

  Future<List<models.Row>> getPendingAdvances() async {
    final companyId = await _companyId();
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('status', 'pending'),
        Query.orderDesc('created_at'),
      ],
    );
    return response.rows;
  }

  Future<AdvanceBalanceInfo> getEmployeeAdvanceBalance(
    String employeeId,
  ) async {
    final profile = await _requireEmployeeInCurrentCompany(employeeId);
    final now = DateTime.now();
    final period = PayrollPeriodService.getCurrentPayrollPeriod(now);

    final workingDaysInPeriod = PayrollPeriodService.countWorkingDays(
      period.periodStart,
      period.periodEnd,
    );

    final attendanceData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: [
        Query.equal('company_id', profile.companyId),
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
    for (final doc in attendanceData.rows) {
      final status = doc.data['status'];
      if (status == 'present' || status == 'late' || doc.data['check_in'] != null) {
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
        Query.equal('company_id', profile.companyId),
        Query.equal('employee_id', employeeId),
        Query.greaterThanEqual(
          'created_at',
          period.periodStart.toIso8601String(),
        ),
        Query.lessThanEqual('created_at', period.periodEnd.toIso8601String()),
      ],
    );

    num previousAdvances = 0;
    for (final doc in advancesData.rows) {
      final status = doc.data['status'];
      if (status == 'pending' || status == 'approved' || status == 'paid') {
        previousAdvances += (doc.data['principal_amount'] as num? ?? 0);
      }
    }

    final penaltiesData = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: [
        Query.equal('company_id', profile.companyId),
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
    for (final doc in penaltiesData.rows) {
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
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    await _requireEmployeeInCurrentCompany(employeeId);
    await _requireCompanyRow(
      tableId: AppConstants.advancesTable,
      rowId: advanceId,
      companyId: scopedCompanyId,
      employeeId: employeeId,
    );

    if (status == 'approved') {
      final balanceInfo = await getEmployeeAdvanceBalance(employeeId);
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

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': scopedCompanyId,
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
        Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.read(Role.team(scopedCompanyId, AppRoles.financialManager)),
      ],
    );
  }

  Future<List<models.Row>> getPendingLeaves() async {
    final companyId = await _companyId();
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: [
        Query.equal('company_id', companyId),
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
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    await _requireEmployeeInCurrentCompany(employeeId);
    await _requireCompanyRow(
      tableId: AppConstants.leaveRequestsTable,
      rowId: leaveId,
      companyId: scopedCompanyId,
      employeeId: employeeId,
    );

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      rowId: leaveId,
      data: {'status': status, 'reviewed_at': DateTime.now().toIso8601String()},
    );

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsTable,
      rowId: ID.unique(),
      data: {
        'company_id': scopedCompanyId,
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
        Permission.read(Role.team(scopedCompanyId, AppRoles.hrAdmin)),
        Permission.read(Role.team(scopedCompanyId, AppRoles.generalManager)),
      ],
    );
  }

  Future<AttendancePolicyModel> getActiveAttendancePolicy(
    String companyId,
  ) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendancePoliciesTable,
      queries: [
        Query.equal('company_id', scopedCompanyId),
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
    final companyId = await _companyId();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendancePoliciesTable,
      rowId: policy.id,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('سياسة الدوام لا تتبع شركة المستخدم الحالية.');
    }
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
    await _requireEmployeeInCurrentCompany(employeeId);
    await updateEmployeeCredentials(
      profileId: employeeId,
      profileUpdates: {'active': isActive},
    );
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
    await _requireEmployeeInCurrentCompany(employeeId);
    final profileUpdates = <String, dynamic>{};
    if (fullName != null) profileUpdates['fullName'] = fullName.trim();
    if (departmentName != null) {
      profileUpdates['departmentName'] = departmentName.trim();
    }
    if (jobTitleId != null) profileUpdates['jobTitleId'] = jobTitleId.trim();
    if (jobTitleName != null) {
      profileUpdates['jobTitleName'] = jobTitleName.trim();
    }
    profileUpdates['biometricEmployeeId'] = biometricEmployeeId?.trim() ?? '';
    if (phone != null) profileUpdates['phone'] = phone.trim();
    if (baseSalary != null) profileUpdates['baseSalary'] = baseSalary;
    if (monthlyBonus != null) profileUpdates['monthlyBonus'] = monthlyBonus;
    if (dailyWorkHours != null) {
      profileUpdates['dailyWorkHours'] = dailyWorkHours;
    }
    if (active != null) profileUpdates['active'] = active;

    await updateEmployeeCredentials(
      profileId: employeeId,
      profileUpdates: profileUpdates,
    );
  }

  Future<void> updateEmployeeBiometricId(
    String employeeId,
    String? biometricId,
  ) async {
    await _requireEmployeeInCurrentCompany(employeeId);
    await updateEmployeeCredentials(
      profileId: employeeId,
      profileUpdates: {'biometricEmployeeId': biometricId?.trim() ?? ''},
    );
  }

  Future<void> updateEmployeeCredentials({
    required String profileId,
    String? newEmployeeNumber,
    String? newPassword,
    bool? mustChangePassword,
    Map<String, dynamic>? profileUpdates,
  }) async {
    await _requireEmployeeInCurrentCompany(profileId);
    final payload = {
      'profileId': profileId,
      if (newEmployeeNumber != null && newEmployeeNumber.trim().isNotEmpty)
        'newEmployeeNumber': newEmployeeNumber.trim(),
      if (newPassword != null && newPassword.trim().isNotEmpty)
        'newPassword': newPassword.trim(),
      if (mustChangePassword != null) 'mustChangePassword': mustChangePassword,
      if (profileUpdates != null && profileUpdates.isNotEmpty)
        'profileUpdates': profileUpdates,
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
