class AppRoles {
  static const hrAdmin = 'hr_admin';
  static const generalManager = 'general_manager';
  static const financialManager = 'financial_manager';
  static const employee = 'employee';

  static const managementRoles = [hrAdmin, generalManager, financialManager];
  static const assignableRoles = [
    employee,
    generalManager,
    financialManager,
    hrAdmin,
  ];

  static String label(String role) {
    switch (role) {
      case hrAdmin:
        return 'الموارد البشرية';
      case generalManager:
        return 'المدير العام';
      case financialManager:
        return 'المدير المالي';
      case employee:
        return 'موظف';
      default:
        return role;
    }
  }

  static bool isManagement(String role) => managementRoles.contains(role);
  static bool isHr(String role) => role == hrAdmin;
  static bool isGeneralManager(String role) => role == generalManager;
  static bool isFinancialManager(String role) => role == financialManager;

  static bool canCreateEmployees(String role) => isHr(role);
  static bool canEditEmployees(String role) => isHr(role);
  static bool canViewEmployees(String role) => isManagement(role);

  static bool canViewAttendance(String role) => isManagement(role);
  static bool canManageAttendance(String role) =>
      isHr(role) || isGeneralManager(role);

  static bool canViewPenalties(String role) => isManagement(role);
  static bool canManagePenalties(String role) =>
      isHr(role) || isGeneralManager(role);

  static bool canViewPayroll(String role) => isManagement(role);
  static bool canManagePayroll(String role) =>
      isHr(role) || isFinancialManager(role);

  static bool canViewAdvances(String role) => isManagement(role);
  static bool canManageAdvances(String role) =>
      isHr(role) || isFinancialManager(role);

  static bool canManageLeaveRequests(String role) =>
      isHr(role) || isGeneralManager(role);
  static bool canManageDocuments(String role) => isHr(role);
  static bool canManageAnnouncements(String role) =>
      isHr(role) || isGeneralManager(role);
  static bool canViewAuditLogs(String role) => isHr(role);
  static bool canManageFunds(String role) =>
      isHr(role) || isFinancialManager(role);

  static bool canViewReports(String role) => isManagement(role);
  static bool canViewEmployeeFullReport(String role) => isHr(role);
  static bool canViewAttendanceReports(String role) => canViewAttendance(role);
  static bool canViewPayrollReports(String role) => canViewPayroll(role);
  static bool canViewAdvancesReports(String role) => canViewAdvances(role);
  static bool canViewPenaltiesReports(String role) => canViewPenalties(role);
  static bool canViewLeavesReports(String role) => canManageLeaveRequests(role);
  static bool canViewOvertimeReports(String role) => canViewAttendance(role);
  static bool canViewDocumentReports(String role) => canManageDocuments(role);

  static List<AdminModule> modulesFor(String role) {
    final modules = <AdminModule>[];

    if (canViewEmployees(role)) {
      modules.add(
        AdminModule(
          type: AdminModuleType.employees,
          category: AdminModuleCategory.people,
          title: 'الموظفون',
          description: canEditEmployees(role)
              ? 'إضافة وتعديل وتعطيل حسابات الموظفين'
              : 'استعراض دليل الموظفين وبياناتهم الأساسية',
          iconName: 'people',
          manageMode: canEditEmployees(role),
        ),
      );
    }

    if (isHr(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.jobTitles,
          category: AdminModuleCategory.people,
          title: 'المسميات الوظيفية',
          description: 'إدارة المسميات الوظيفية المستخدمة داخل النظام',
          iconName: 'work',
          manageMode: true,
        ),
      );
    }

    if (canManageAttendance(role)) {
      modules.addAll(const [
        AdminModule(
          type: AdminModuleType.attendancePolicy,
          category: AdminModuleCategory.attendance,
          title: 'سياسات الدوام',
          description: 'إعداد فترات السماح وقواعد احتساب الحضور والتأخير',
          iconName: 'calendar',
          manageMode: true,
        ),
        AdminModule(
          type: AdminModuleType.shifts,
          category: AdminModuleCategory.attendance,
          title: 'الورديات',
          description: 'إضافة وتعديل الورديات وأوقات العمل',
          iconName: 'schedule',
          manageMode: true,
        ),
        AdminModule(
          type: AdminModuleType.shiftAssignments,
          category: AdminModuleCategory.attendance,
          title: 'تعيين دوام الموظفين',
          description: 'ربط الموظفين بالورديات الثابتة أو المتغيرة',
          iconName: 'assignment_ind',
          manageMode: true,
        ),
        AdminModule(
          type: AdminModuleType.monthlySchedules,
          category: AdminModuleCategory.attendance,
          title: 'الجداول الشهرية',
          description: 'توليد جدول الدوام الشهري الفعلي لكل موظف',
          iconName: 'calendar_month',
          manageMode: true,
        ),
        AdminModule(
          type: AdminModuleType.biometricImport,
          category: AdminModuleCategory.attendance,
          title: 'استيراد البصمة',
          description: 'استيراد حركات الدخول والخروج من جهاز البصمة',
          iconName: 'fingerprint',
          manageMode: true,
        ),
        AdminModule(
          type: AdminModuleType.overtime,
          category: AdminModuleCategory.attendance,
          title: 'الوقت الإضافي',
          description: 'مراجعة واعتماد أو رفض الساعات الإضافية',
          iconName: 'timer',
          manageMode: true,
        ),
      ]);
    }

    if (canManageLeaveRequests(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.leaves,
          category: AdminModuleCategory.approvals,
          title: 'الإجازات والاستئذان',
          description: 'مراجعة طلبات الإجازات واعتمادها أو رفضها',
          iconName: 'event_available',
          manageMode: true,
        ),
      );
    }

    if (canManagePenalties(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.penalties,
          category: AdminModuleCategory.approvals,
          title: 'الجزاءات',
          description: 'إضافة ومراجعة الجزاءات وتأثيرها المالي',
          iconName: 'gavel',
          manageMode: true,
        ),
      );
    }

    if (canManagePayroll(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.payroll,
          category: AdminModuleCategory.finance,
          title: 'الرواتب',
          description: 'احتساب ومراجعة واعتماد مسير الرواتب',
          iconName: 'payments',
          manageMode: true,
        ),
      );
    }

    if (canManageAdvances(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.advances,
          category: AdminModuleCategory.finance,
          title: 'السلف',
          description: 'مراجعة السلف والأقساط واعتماد عمليات الصرف',
          iconName: 'wallet',
          manageMode: true,
        ),
      );
    }

    if (canManageFunds(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.funds,
          category: AdminModuleCategory.finance,
          title: 'الصندوق',
          description: 'إدارة الصناديق والحركات المالية المرتبطة بها',
          iconName: 'account_balance',
          manageMode: true,
        ),
      );
    }

    if (canManageDocuments(role)) {
      modules.add(
        const AdminModule(
          type: AdminModuleType.documents,
          category: AdminModuleCategory.system,
          title: 'مستندات الموظفين',
          description: 'إدارة العقود والهويات والشهادات والملفات',
          iconName: 'folder',
          manageMode: true,
        ),
      );
    }

    // Audit log permissions are kept for the future data source, but no
    // unfinished navigation item is shown until an audit screen is implemented.
    return modules;
  }
}

enum AdminModuleType {
  employees,
  jobTitles,
  attendancePolicy,
  shifts,
  shiftAssignments,
  monthlySchedules,
  biometricImport,
  overtime,
  leaves,
  penalties,
  payroll,
  advances,
  funds,
  documents,
  audit,
}

enum AdminModuleCategory { people, attendance, approvals, finance, system }

class AdminModule {
  final AdminModuleType type;
  final AdminModuleCategory category;
  final String title;
  final String description;
  final String iconName;
  final bool manageMode;

  const AdminModule({
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.iconName,
    required this.manageMode,
  });
}
