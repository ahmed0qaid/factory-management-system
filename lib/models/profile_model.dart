import '../permissions/role_permissions.dart';

class EmploymentStatus {
  static const active = 'active';
  static const suspended = 'suspended';
  static const terminated = 'terminated';

  static const values = [active, suspended, terminated];

  static String label(String status) {
    switch (status) {
      case active:
        return 'نشط';
      case suspended:
        return 'موقوف مؤقتًا';
      case terminated:
        return 'منتهي الخدمة';
      default:
        return status;
    }
  }
}

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
  final String employmentStatus;
  final String? statusReason;
  final DateTime? terminationDate;
  final DateTime? statusChangedAt;
  final String? statusChangedBy;

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
    this.employmentStatus = EmploymentStatus.active,
    this.statusReason,
    this.terminationDate,
    this.statusChangedAt,
    this.statusChangedBy,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    final isActive = map['active'] ?? true;
    final storedStatus = map['employment_status']?.toString().trim() ?? '';
    final employmentStatus = EmploymentStatus.values.contains(storedStatus)
        ? storedStatus
        : (isActive ? EmploymentStatus.active : EmploymentStatus.suspended);

    return ProfileModel(
      id: map['id'] ?? map[r'$id'] ?? '',
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
      hireDate: DateTime.tryParse(map['hire_date']?.toString() ?? '') ??
          DateTime.now(),
      baseSalary: map['base_salary'] ?? 0,
      monthlyBonus: map['monthly_bonus'] ?? 0,
      dailyWorkHours: map['daily_work_hours'] as num? ?? 8,
      active: isActive,
      mustChangePassword: map['must_change_password'] ?? false,
      biometricEmployeeId: map['biometric_employee_id'],
      employmentStatus: employmentStatus,
      statusReason: map['status_reason']?.toString(),
      terminationDate: DateTime.tryParse(
        map['termination_date']?.toString() ?? '',
      ),
      statusChangedAt: DateTime.tryParse(
        map['status_changed_at']?.toString() ?? '',
      ),
      statusChangedBy: map['status_changed_by']?.toString(),
    );
  }

  bool get isManagement => AppRoles.isManagement(role);
  bool get isHrAdmin => AppRoles.isHr(role);
  bool get isGeneralManager => AppRoles.isGeneralManager(role);
  bool get isFinancialManager => AppRoles.isFinancialManager(role);
  bool get isActiveEmployment => employmentStatus == EmploymentStatus.active;
  bool get isSuspended => employmentStatus == EmploymentStatus.suspended;
  bool get isTerminated => employmentStatus == EmploymentStatus.terminated;
  num get monthlyEntitlement => baseSalary + monthlyBonus;
  String get roleLabel => AppRoles.label(role);
  String get employmentStatusLabel => EmploymentStatus.label(employmentStatus);
}