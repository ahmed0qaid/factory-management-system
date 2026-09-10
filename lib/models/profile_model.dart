import '../permissions/role_permissions.dart';

class ProfileModel {
  final String id;
  final String companyId;
  final String employeeNumber;
  final String fullName;
  final String role;
  final String? phone;
  final String? photoPath;
  final String? departmentId;
  final String? departmentName;
  final String? jobTitleId;
  final String? jobTitleName;
  final DateTime hireDate;
  final num baseSalary;
  final num monthlyBonus;
  final num dailyWorkHours;
  final bool active;
  final bool mustChangePassword;
  final String? biometricEmployeeId;

  ProfileModel({
    required this.id,
    required this.companyId,
    required this.employeeNumber,
    required this.fullName,
    required this.role,
    this.phone,
    this.photoPath,
    this.departmentId,
    this.departmentName,
    this.jobTitleId,
    this.jobTitleName,
    required this.hireDate,
    required this.baseSalary,
    required this.monthlyBonus,
    this.dailyWorkHours = 8,
    required this.active,
    required this.mustChangePassword,
    this.biometricEmployeeId,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] ?? map['\$id'] ?? '',
      companyId: map['company_id'] ?? '',
      employeeNumber: map['employee_number'] ?? '',
      fullName: map['full_name'] ?? '',
      role: map['role'] ?? 'employee',
      phone: map['phone'],
      photoPath: map['photo_path'],
      departmentId: map['department_id'],
      departmentName: map['department_name'],
      jobTitleId: map['job_title_id'],
      jobTitleName: map['job_title_name'],
      hireDate: DateTime.tryParse(map['hire_date'] ?? '') ?? DateTime.now(),
      baseSalary: map['base_salary'] ?? 0,
      monthlyBonus: map['monthly_bonus'] ?? 0,
      dailyWorkHours: map['daily_work_hours'] as num? ?? 8,
      active: map['active'] ?? true,
      mustChangePassword: map['must_change_password'] ?? false,
      biometricEmployeeId: map['biometric_employee_id'],
    );
  }

  bool get isManagement => AppRoles.isManagement(role);
  bool get isHrAdmin => AppRoles.isHr(role);
  bool get isGeneralManager => AppRoles.isGeneralManager(role);
  bool get isFinancialManager => AppRoles.isFinancialManager(role);
  num get monthlyEntitlement => baseSalary + monthlyBonus;
  String get roleLabel => AppRoles.label(role);
}
