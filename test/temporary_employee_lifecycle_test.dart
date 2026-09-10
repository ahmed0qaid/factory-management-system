import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hr_employee_system/services/appwrite_service.dart';
import 'package:hr_employee_system/services/auth_service.dart';
import 'package:hr_employee_system/services/admin_biometrics_service.dart';
import 'package:hr_employee_system/services/biometric_preprocessor.dart';
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
      endpoint: env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1',
      projectId: env['APPWRITE_PROJECT_ID']!,
      databaseId: env['APPWRITE_DATABASE_ID']!,
      createEmployeeFunctionId: 'create_employee',
    );
  });

  test('Temporary Employee Lifecycle Test (TMP_UNKNOWN_999_TEST)', () async {
    final authService = AuthService();
    final biometricsService = AdminBiometricsService();
    const companyId = 'company_main';
    const tmpId = 'TMP_UNKNOWN_999_TEST';

    print('Logging in as hr001...');
    await authService.signInWithEmployeeNumber(
      employeeNumber: 'hr001',
      password: '12345678',
    );
    print('Logged in.');

    print('1. Testing creation of pending temporary employee...');
    final sum1 = PreprocessSummary()
      ..totalPunches = 1
      ..matchedEmployees = 0
      ..groups = [
        ProcessedGroup(
          biometricId: tmpId,
          physicalDate: DateTime.now(),
          punches: [
            BiometricPunch(
              id: 'p1',
              biometricId: tmpId,
              time: DateTime.now(),
              isValid: true,
              role: PunchRole.checkIn,
            ),
          ],
        ),
      ];

    await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'test_lifecycle_1.txt',
      summary: sum1,
      rawLogs: [
        {'biometric_employee_id': tmpId, 'punch_time': DateTime.now()},
      ],
    );

    var pendingList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'pending',
    );
    var isPending = pendingList.any((e) => e.biometricEmployeeId == tmpId);
    expect(isPending, true, reason: 'Employee should be created as pending.');
    print('SUCCESS: Created as pending.');

    print('2. Testing idempotency (no duplicate creation)...');
    final sum2 = PreprocessSummary()
      ..totalPunches = 1
      ..matchedEmployees = 0
      ..groups = [
        ProcessedGroup(
          biometricId: tmpId,
          physicalDate: DateTime.now(),
          punches: [
            BiometricPunch(
              id: 'p2',
              biometricId: tmpId,
              time: DateTime.now(),
              isValid: true,
              role: PunchRole.checkOut,
            ),
          ],
        ),
      ];
    await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'test_lifecycle_2.txt',
      summary: sum2,
      rawLogs: [
        {'biometric_employee_id': tmpId, 'punch_time': DateTime.now()},
      ],
    );

    pendingList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'pending',
    );
    var matchingEmps = pendingList
        .where((e) => e.biometricEmployeeId == tmpId)
        .toList();
    expect(
      matchingEmps.length,
      1,
      reason: 'There should still be exactly 1 pending record.',
    );
    print('SUCCESS: Idempotency confirmed (no duplicates, counts updated).');

    print('3. Testing rejection...');
    final tempRowId = matchingEmps.first.id;
    await biometricsService.rejectTemporaryEmployee(tempRowId);

    var rejectedList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'rejected',
    );
    var isRejected = rejectedList.any((e) => e.biometricEmployeeId == tmpId);
    expect(
      isRejected,
      true,
      reason: 'Employee should now be in rejected list.',
    );
    print('SUCCESS: Rejected successfully.');

    print('4. Testing reappearance after rejection...');
    final sum3 = PreprocessSummary()
      ..totalPunches = 1
      ..matchedEmployees = 0
      ..groups = [
        ProcessedGroup(
          biometricId: tmpId,
          physicalDate: DateTime.now(),
          punches: [
            BiometricPunch(
              id: 'p3',
              biometricId: tmpId,
              time: DateTime.now(),
              isValid: true,
              role: PunchRole.checkIn,
            ),
          ],
        ),
      ];
    await biometricsService.commitProcessedBiometricImport(
      companyId: companyId,
      fileName: 'test_lifecycle_3.txt',
      summary: sum3,
      rawLogs: [
        {'biometric_employee_id': tmpId, 'punch_time': DateTime.now()},
      ],
    );

    pendingList = await biometricsService.getTemporaryEmployees(
      companyId,
      status: 'pending',
    );
    isPending = pendingList.any((e) => e.biometricEmployeeId == tmpId);
    expect(
      isPending,
      true,
      reason: 'Employee should return to pending after new import.',
    );
    print('SUCCESS: Returned to pending after new import.');
  });
}
