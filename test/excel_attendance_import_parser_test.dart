import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_system/services/excel_attendance_import_parser.dart';

void main() {
  test('parses emps.xlsx and preserves missing actual checkout', () {
    final file = File('test_data/emps.xlsx');
    final parsed = ExcelAttendanceImportParser.parse(file.readAsBytesSync());
    final summary = parsed.summary;

    expect(summary.excelRowsRead, 126);
    expect(summary.absentCases, greaterThan(0));
    expect(summary.missingCheckOuts, greaterThan(0));

    final missingCheckoutGroup = summary.groups.firstWhere(
      (group) => group.actualCheckIn != null && group.actualCheckOut == null,
    );

    expect(missingCheckoutGroup.needsReview, isTrue);
    expect(missingCheckoutGroup.actualCheckOut, isNull);
    expect(missingCheckoutGroup.expectedOvertimeMinutes, 0);

    final absentGroup = summary.groups.firstWhere((group) => group.isAbsent);
    expect(absentGroup.needsReview, isFalse);
    expect(absentGroup.actualCheckIn, isNull);
    expect(absentGroup.actualCheckOut, isNull);
  });
}
