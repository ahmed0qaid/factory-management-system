import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_system/permissions/role_permissions.dart';

void main() {
  group('Admin navigation modules', () {
    test('HR gets configuration and management modules without placeholders', () {
      final modules = AppRoles.modulesFor(AppRoles.hrAdmin);
      final types = modules.map((module) => module.type).toSet();

      expect(types, contains(AdminModuleType.employees));
      expect(types, contains(AdminModuleType.attendancePolicy));
      expect(types, contains(AdminModuleType.shifts));
      expect(types, contains(AdminModuleType.shiftAssignments));
      expect(types, contains(AdminModuleType.monthlySchedules));
      expect(types, contains(AdminModuleType.biometricImport));
      expect(types, contains(AdminModuleType.overtime));
      expect(types, contains(AdminModuleType.payroll));
      expect(types, contains(AdminModuleType.advances));
      expect(types, contains(AdminModuleType.documents));
      expect(types, isNot(contains(AdminModuleType.audit)));
    });

    test('general manager gets approvals but not structural HR configuration', () {
      final modules = AppRoles.modulesFor(AppRoles.generalManager);
      final types = modules.map((module) => module.type).toSet();
      final employees = modules.firstWhere(
        (module) => module.type == AdminModuleType.employees,
      );

      expect(employees.manageMode, isFalse);
      expect(types, contains(AdminModuleType.employees));
      expect(types, contains(AdminModuleType.overtime));
      expect(types, contains(AdminModuleType.leaves));
      expect(types, contains(AdminModuleType.penalties));
      expect(types, isNot(contains(AdminModuleType.attendancePolicy)));
      expect(types, isNot(contains(AdminModuleType.shifts)));
      expect(types, isNot(contains(AdminModuleType.shiftAssignments)));
      expect(types, isNot(contains(AdminModuleType.monthlySchedules)));
      expect(types, isNot(contains(AdminModuleType.biometricImport)));
      expect(types, isNot(contains(AdminModuleType.payroll)));
      expect(types, isNot(contains(AdminModuleType.advances)));
      expect(types, isNot(contains(AdminModuleType.documents)));
    });

    test('financial manager receives financial management modules only', () {
      final modules = AppRoles.modulesFor(AppRoles.financialManager);
      final types = modules.map((module) => module.type).toSet();
      final employees = modules.firstWhere(
        (module) => module.type == AdminModuleType.employees,
      );

      expect(employees.manageMode, isFalse);
      expect(types, contains(AdminModuleType.payroll));
      expect(types, contains(AdminModuleType.advances));
      expect(types, contains(AdminModuleType.funds));
      expect(types, isNot(contains(AdminModuleType.attendancePolicy)));
      expect(types, isNot(contains(AdminModuleType.penalties)));
      expect(types, isNot(contains(AdminModuleType.overtime)));
    });

    test('ordinary employee has no admin modules', () {
      expect(AppRoles.modulesFor(AppRoles.employee), isEmpty);
    });
  });

  group('Permission intent', () {
    test('attendance setup stays HR-only while review access can include manager', () {
      expect(AppRoles.canConfigureAttendance(AppRoles.hrAdmin), isTrue);
      expect(
        AppRoles.canConfigureAttendance(AppRoles.generalManager),
        isFalse,
      );
      expect(AppRoles.canManageAttendance(AppRoles.generalManager), isTrue);
    });
  });
}
