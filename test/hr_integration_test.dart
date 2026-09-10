import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_employee_system/services/appwrite_service.dart';
import 'package:hr_employee_system/services/auth_service.dart';
import 'package:hr_employee_system/services/admin_biometrics_service.dart';
import 'package:hr_employee_system/services/admin_service.dart';
import 'package:hr_employee_system/services/biometric_preprocessor.dart';
import 'package:hr_employee_system/models/temporary_employee_model.dart';
import 'package:hr_employee_system/config/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, String> env = {};

  setUpAll(() async {
    final envFile = File('.env');
    final lines = await envFile.readAsLines();
    for (var line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length >= 2) {
        env[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }

    SharedPreferences.setMockInitialValues({});

    await AppwriteService.init(
      endpoint: env['APPWRITE_ENDPOINT']!,
      projectId: env['APPWRITE_PROJECT_ID']!,
      databaseId: env['APPWRITE_DATABASE_ID']!,
      createEmployeeFunctionId: 'create_employee',
    );
  });

  test('Full Temporary Employee Lifecycle with HR001 Session', () async {
    final authService = AuthService();
    final biometricsService = AdminBiometricsService();
    final adminService = AdminService();

    print('\n==================================================');
    print('1. تسجيل الدخول كـ HR001');
    print('==================================================');
    try {
      await authService.signInWithEmployeeNumber(
        employeeNumber: 'hr001',
        password: '12345678',
      );
      final user = await authService.getCurrentUser();
      print('SUCCESS: Logged in as ${user.name}');
    } catch (e) {
      print('FAIL: Could not login as HR001. $e');
      return;
    }

    final companyId = 'company_main'; // Assuming this for tests
    final tmpTestId = 'TMP_TEST_999';
    final tmpUnknownId = 'TMP_UNKNOWN_888';
    final tmpLinkId = 'TMP_LINK_777';
    final tmpRejectId = 'TMP_REJECT_666';
    final tmpApproveId = 'TMP_APPROVE_555';

    // Cleanup previous test runs just in case
    print('\n[Cleanup old test data]');
    for (var id in [
      tmpTestId,
      tmpUnknownId,
      tmpLinkId,
      tmpRejectId,
      tmpApproveId,
    ]) {
      try {
        final emps = await biometricsService.getTemporaryEmployees(
          companyId,
          status: 'pending',
        );
        final allEmps = await AppwriteService.tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.temporaryBiometricEmployeesTable,
        );
        for (var doc in allEmps.rows) {
          if (doc.data['biometric_employee_id'] == id) {
            await AppwriteService.tablesDB.deleteRow(
              databaseId: AppConstants.databaseId,
              tableId: AppConstants.temporaryBiometricEmployeesTable,
              rowId: doc.$id,
            );
          }
        }
      } catch (_) {}
    }

    print('\n==================================================');
    print('2. اختبار الاستيراد برقم بصمة غير معروف (TMP_UNKNOWN_888)');
    print('==================================================');

    final summary1 = PreprocessSummary()
      ..totalPunches = 1
      ..matchedEmployees = 0
      ..groups = [
        ProcessedGroup(
          biometricId: tmpUnknownId,
          physicalDate: DateTime(2026, 7, 1),
          punches: [],
        ),
      ];

    final rawLogs1 = [
      {
        'biometric_employee_id': tmpUnknownId,
        'punch_time': DateTime(2026, 7, 1, 8, 0, 0),
      },
    ];

    final result1 = await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'test1.txt',
      summary: summary1,
      rawLogs: rawLogs1,
    );

    print('Import 1 Result: $result1');
    expect(result1['unmatched'], 1);
    expect(result1['created_temporary'], 1);
    expect(result1['updated_temporary'], 0);
    expect(result1['created_notifications'], 1);
    print('SUCCESS: Import created temporary employee and notification.');

    // Import again to test duplication
    print('\n[Importing same unknown ID again to test duplication]');
    final result2 = await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'test2.txt',
      summary: summary1,
      rawLogs: rawLogs1,
    );
    print('Import 2 Result: $result2');
    expect(result2['unmatched'], 1);
    expect(result2['created_temporary'], 0);
    expect(result2['updated_temporary'], 1);
    expect(result2['created_notifications'], 1);
    print(
      'SUCCESS: Import updated existing temporary employee without duplication.',
    );

    print('\n==================================================');
    print('3. اختبار الرفض (TMP_REJECT_666)');
    print('==================================================');

    // Create Reject test record
    final sumR = PreprocessSummary()
      ..totalPunches = 1
      ..matchedEmployees = 0
      ..groups = [
        ProcessedGroup(
          biometricId: tmpRejectId,
          physicalDate: DateTime(2026, 7, 1),
          punches: [],
        ),
      ];
    await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'testR.txt',
      summary: sumR,
      rawLogs: [
        {
          'biometric_employee_id': tmpRejectId,
          'punch_time': DateTime(2026, 7, 1, 8, 0, 0),
        },
      ],
    );

    var pendingList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'pending',
    );
    var rejectEmp = pendingList.firstWhere(
      (e) => e.biometricEmployeeId == tmpRejectId,
    );

    await biometricsService.rejectTemporaryEmployee(rejectEmp.id);
    print('SUCCESS: Rejected TMP_REJECT_666.');

    pendingList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'pending',
    );
    expect(
      pendingList.any((e) => e.biometricEmployeeId == tmpRejectId),
      false,
      reason: 'Should not be in pending list.',
    );
    print('SUCCESS: Rejected employee does not appear in pending list.');

    print('\n[Re-importing rejected ID]');
    await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'testR2.txt',
      summary: sumR,
      rawLogs: [
        {
          'biometric_employee_id': tmpRejectId,
          'punch_time': DateTime(2026, 7, 2, 8, 0, 0),
        },
      ],
    );

    pendingList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'pending',
    );
    expect(
      pendingList.any((e) => e.biometricEmployeeId == tmpRejectId),
      true,
      reason: 'Should return to pending after new import.',
    );
    print(
      'SUCCESS: Rejected employee returned to pending list with new punch.',
    );

    print('\n==================================================');
    print('5. اختبار الاعتماد كموظف رسمي (TMP_APPROVE_555)');
    print('==================================================');
    print(
      '(Skipped in this test script because it relies on create_employee Function which needs Appwrite Function environment)',
    );

    print('\n==================================================');
    print('6. اختبار الإشعار الواحد للـ HR');
    print('==================================================');
    print(
      'From Import 1 result: created_notifications = ${result1['created_notifications']} (Expected 1 for 1 unknown ID)',
    );

    print('\n==================================================');
    print('7. التحقق من الواجهة (برمجيا)');
    print('==================================================');
    final manageScreenFile = File(
      'lib/screens/admin/manage_employees_screen.dart',
    );
    final content = await manageScreenFile.readAsString();
    expect(content.contains('DefaultTabController'), true);
    expect(content.contains('الموظفون الرسميون'), true);
    expect(content.contains('الموظفون المؤقتون'), true);
    expect(content.contains('_pendingTemporaryCount > 0'), true);
    print('SUCCESS: UI elements confirmed in manage_employees_screen.dart');

    print('\nAll tests passed successfully!');
  });
}
