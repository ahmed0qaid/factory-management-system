import 'dart:convert';

import '../config/constants.dart';
import '../models/profile_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

class EmployeeLifecycleService {
  Future<void> createEmployee({
    required String employeeNumber,
    required String fullName,
    required String temporaryPassword,
    required String role,
    required DateTime hireDate,
    required String departmentName,
    String? phone,
    String? jobTitleId,
    String? jobTitleName,
    num baseSalary = 0,
    num monthlyBonus = 0,
    String? biometricEmployeeId,
  }) async {
    if (!AppRoles.assignableRoles.contains(role)) {
      throw Exception('دور غير مسموح');
    }
    if (departmentName.trim().isEmpty) {
      throw Exception('القسم مطلوب عند إنشاء الموظف.');
    }

    final payload = {
      'employeeNumber': employeeNumber.trim(),
      'fullName': fullName.trim(),
      'temporaryPassword': temporaryPassword,
      'role': role,
      'departmentName': departmentName.trim(),
      'hireDate': hireDate.toIso8601String(),
      'baseSalary': baseSalary,
      'monthlyBonus': monthlyBonus,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (biometricEmployeeId != null && biometricEmployeeId.trim().isNotEmpty)
        'biometricEmployeeId': biometricEmployeeId.trim(),
      if (jobTitleId != null && jobTitleId.trim().isNotEmpty)
        'jobTitleId': jobTitleId.trim(),
      if (jobTitleName != null && jobTitleName.trim().isNotEmpty)
        'jobTitleName': jobTitleName.trim(),
    };

    await _executeUpdateSafeFunction(
      functionId: AppConstants.createEmployeeFunctionId,
      payload: payload,
      fallbackError: 'فشل إنشاء الموظف',
    );
  }

  Future<void> changeEmploymentStatus({
    required ProfileModel employee,
    required String employmentStatus,
    required String reason,
    DateTime? terminationDate,
  }) async {
    await CompanyContextService.requireCompany(employee.companyId);

    if (!EmploymentStatus.values.contains(employmentStatus)) {
      throw Exception('الحالة الوظيفية غير صالحة.');
    }
    if (employee.isHrAdmin && employmentStatus != EmploymentStatus.active) {
      throw Exception('لا يمكن تعليق أو إنهاء حساب الموارد البشرية.');
    }

    final cleanReason = reason.trim();
    if (employmentStatus != EmploymentStatus.active && cleanReason.isEmpty) {
      throw Exception('سبب تغيير الحالة مطلوب.');
    }
    if (employmentStatus == EmploymentStatus.terminated &&
        terminationDate == null) {
      throw Exception('تاريخ انتهاء الخدمة مطلوب.');
    }

    final payload = {
      'profileId': employee.id,
      'profileUpdates': {
        'employmentStatus': employmentStatus,
        'statusReason': employmentStatus == EmploymentStatus.active
            ? ''
            : cleanReason,
        'terminationDate': employmentStatus == EmploymentStatus.terminated
            ? terminationDate!.toIso8601String()
            : '',
      },
    };

    await _executeUpdateSafeFunction(
      functionId: AppConstants.updateEmployeeCredentialsFunctionId,
      payload: payload,
      fallbackError: 'فشل تحديث الحالة الوظيفية',
    );
  }

  Future<void> updateHireDate({
    required ProfileModel employee,
    required DateTime hireDate,
  }) async {
    await CompanyContextService.requireCompany(employee.companyId);
    await _executeUpdateSafeFunction(
      functionId: AppConstants.updateEmployeeCredentialsFunctionId,
      payload: {
        'profileId': employee.id,
        'profileUpdates': {'hireDate': hireDate.toIso8601String()},
      },
      fallbackError: 'فشل تحديث تاريخ التعيين',
    );
  }

  Future<void> _executeUpdateSafeFunction({
    required String functionId,
    required Map<String, dynamic> payload,
    required String fallbackError,
  }) async {
    final execution = await AppwriteService.functions.createExecution(
      functionId: functionId,
      body: jsonEncode(payload),
      xasync: false,
    );

    if (execution.status.name.toLowerCase() != 'completed') {
      throw Exception(
        execution.errors.isNotEmpty ? execution.errors : fallbackError,
      );
    }

    final response = jsonDecode(
      execution.responseBody.isEmpty ? '{}' : execution.responseBody,
    );
    if (response is Map && response['success'] != true) {
      throw Exception(response['error'] ?? fallbackError);
    }
  }
}
