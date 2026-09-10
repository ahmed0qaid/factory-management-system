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
          title: 'الموظفون',
          description: isHr(role)
              ? 'إضافة وتعديل وتعطيل الحسابات'
              : 'عرض بيانات الموظفين الأساسية',
          iconName: 'people',
        ),
      );
      if (isHr(role)) {
        modules.add(
          const AdminModule(
            title: 'المسميات الوظيفية',
            description: 'إدارة المسميات الوظيفية في النظام',
            iconName: 'work',
          ),
        );
      }
    }
    if (canViewAttendance(role)) {
      modules.add(
        AdminModule(
          title: 'سياسات الدوام',
          description: 'إعداد فترات السماح وقواعد الاحتساب',
          iconName: 'calendar',
        ),
      );

      if (canManageAttendance(role)) {
        modules.add(
          const AdminModule(
            title: 'إدارة الورديات',
            description: 'إضافة وتعديل الورديات وأوقات العمل',
            iconName: 'schedule',
          ),
        );
        modules.add(
          const AdminModule(
            title: 'تعيين دوام الموظفين',
            description: 'ربط الموظفين بالورديات الثابتة أو المتغيرة',
            iconName: 'assignment_ind',
          ),
        );
        modules.add(
          const AdminModule(
            title: 'توليد الجداول',
            description: 'توليد جدول الدوام الشهري الفعلي لكل موظف',
            iconName: 'calendar_month',
          ),
        );
        modules.add(
          const AdminModule(
            title: 'استيراد البصمة',
            description: 'استيراد ملفات الدخول والخروج من الجهاز',
            iconName: 'fingerprint',
          ),
        );
        modules.add(
          const AdminModule(
            title: 'إدارة الوقت الإضافي',
            description: 'مراجعة واعتماد أو رفض الساعات الإضافية',
            iconName: 'timer',
          ),
        );
      }
    }
    if (canViewPenalties(role)) {
      modules.add(
        AdminModule(
          title: 'الجزاءات',
          description: canManagePenalties(role)
              ? 'إضافة واعتماد الجزاءات'
              : 'عرض الجزاءات والتأثير المالي',
          iconName: 'gavel',
        ),
      );
    }
    if (canViewPayroll(role)) {
      modules.add(
        AdminModule(
          title: 'الرواتب',
          description: canManagePayroll(role)
              ? 'احتساب واعتماد مسير الرواتب'
              : 'عرض تقارير الرواتب',
          iconName: 'payments',
        ),
      );
    }
    if (canViewAdvances(role)) {
      modules.add(
        AdminModule(
          title: 'السلف',
          description: canManageAdvances(role)
              ? 'اعتماد السلف والأقساط'
              : 'عرض السلف',
          iconName: 'wallet',
        ),
      );
    }
    if (canManageFunds(role)) {
      modules.add(
        const AdminModule(
          title: 'الصندوق',
          description: 'إدارة الصناديق والحركات المالية وتصفيتها',
          iconName: 'account_balance',
        ),
      );
    }
    if (canManageLeaveRequests(role)) {
      modules.add(
        const AdminModule(
          title: 'الإجازات والاستئذان',
          description: 'مراجعة واعتماد طلبات الموظفين',
          iconName: 'event_available',
        ),
      );
    }
    if (canManageDocuments(role)) {
      modules.add(
        const AdminModule(
          title: 'مستندات الموظفين',
          description: 'العقود والهوية والشهادات والملفات',
          iconName: 'folder',
        ),
      );
      modules.add(
        const AdminModule(
          title: 'الصلاحيات وسجل النظام',
          description: 'إدارة الأدوار ومراجعة العمليات الحساسة',
          iconName: 'security',
        ),
      );
    }
    return modules;
  }
}

class AdminModule {
  final String title;
  final String description;
  final String iconName;

  const AdminModule({
    required this.title,
    required this.description,
    required this.iconName,
  });
}
