import 'package:hr_employee_system/services/biometric_preprocessor.dart';

void main() async {
  print('--- Testing Overtime Rules ---');

  await testOvertimeCase(
    1,
    '2023-10-01 14:00:00',
    '2023-10-01 22:00:00',
    '2023-10-01 22:45:00',
    0,
  );
  await testOvertimeCase(
    2,
    '2023-10-01 14:00:00',
    '2023-10-01 22:00:00',
    '2023-10-01 23:00:00',
    0,
  );
  await testOvertimeCase(
    3,
    '2023-10-01 14:00:00',
    '2023-10-01 22:00:00',
    '2023-10-01 23:01:00',
    61,
  );
  await testOvertimeCase(
    4,
    '2023-10-01 14:00:00',
    '2023-10-01 22:00:00',
    '2023-10-01 23:30:00',
    90,
  );
  await testOvertimeCase(
    5,
    '2023-10-01 14:00:00',
    '2023-10-01 22:00:00',
    '2023-10-02 02:03:00',
    243,
  );
  await testOvertimeCase(
    6,
    '2023-10-01 06:00:00',
    '2023-10-01 14:00:00',
    '2023-10-01 16:00:00',
    120,
  );
  await testOvertimeCase(
    7,
    '2023-10-01 22:00:00',
    '2023-10-02 06:00:00',
    '2023-10-02 08:00:00',
    120,
  );
}

Future<void> testOvertimeCase(
  int caseNum,
  String startStr,
  String endStr,
  String outStr,
  int expected,
) async {
  final start = DateTime.parse(startStr);
  final actualOut = DateTime.parse(outStr);

  final rawLogs = [
    {
      'biometric_employee_id': 'EMP$caseNum',
      'employee_id': 'E$caseNum',
      'punch_time': start,
      'is_valid': true,
    },
    {
      'biometric_employee_id': 'EMP$caseNum',
      'employee_id': 'E$caseNum',
      'punch_time': actualOut,
      'is_valid': true,
    },
  ];

  final summary = await BiometricPreprocessor.process(
    rawLogs: rawLogs,
    shiftMode: ShiftSelectionMode.auto,
    duplicateMode: DuplicateHandlingMode.auto,
    validBiometricIds: {'EMP$caseNum': true},
  );

  if (summary.groups.isNotEmpty) {
    final group = summary.groups.first;
    final overtime = group.expectedOvertimeMinutes;
    final passed = overtime == expected;
    print(
      'Case $caseNum: Shift End ${endStr.substring(11, 16)} -> Out ${outStr.substring(11, 16)}',
    );
    print('  Expected Overtime: $expected min');
    print('  Actual Overtime:   $overtime min');
    print('  Result:            ${passed ? "PASSED" : "FAILED"}');
  } else {
    print('Case $caseNum failed to process groups.');
  }
}
