import '../lib/services/excel_attendance_import_parser.dart';

void main() {
  void testDate(String input, String expected) {
    final result = ExcelAttendanceImportParser.parseExcelDate(input);
    final formatted = result != null 
        ? '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}'
        : 'null';
    
    if (formatted == expected) {
      print('PASS: $input => $formatted');
    } else {
      print('FAIL: $input => $formatted (Expected: $expected)');
    }
  }

  print('Testing Date Parser:');
  testDate('1/8/2026', '2026-08-01');
  testDate('2/8/2026', '2026-08-02');
  testDate('26/07/26', '2026-07-26');
  testDate('30/07/26', '2026-07-30');
  
  // Test space at the end
  testDate('30/07/26  ', '2026-07-30');
  
  // Test with dashes
  testDate('30-07-2026', '2026-07-30');
}
