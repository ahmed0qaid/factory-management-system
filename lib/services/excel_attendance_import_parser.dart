import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'biometric_preprocessor.dart';

class ExcelAttendanceImportResult {
  final PreprocessSummary summary;
  final List<Map<String, dynamic>> rawLogs;

  const ExcelAttendanceImportResult({
    required this.summary,
    required this.rawLogs,
  });
}

class ExcelAttendanceImportParser {
  static const invalidFormatMessage =
      'صيغة ملف Excel غير صحيحة. تأكد من وجود الأعمدة المطلوبة.';

  static const List<String> requiredHeaders = [
    'رقم البصمه',
    'الإسم',
    'التاريخ',
    'الحضور المطلوب',
    'الإنصراف المطلوب',
    'الحضور الفعلي',
    'الإنصراف الفعلي',
    'تأخير',
    'إنصراف مبكر',
    'غياب',
  ];

  static ExcelAttendanceImportResult parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedStrings = _readSharedStrings(archive);
    final sheetPath = _firstSheetPath(archive);
    final sheetFile = archive.findFile(sheetPath);

    if (sheetFile == null) {
      throw const FormatException(invalidFormatMessage);
    }

    final sheetXml = XmlDocument.parse(_fileText(sheetFile));
    final rows = sheetXml.findAllElements('row').toList();
    if (rows.isEmpty) {
      throw const FormatException(invalidFormatMessage);
    }

    final headerRow = _readRow(rows.first, sharedStrings);
    for (var i = 0; i < requiredHeaders.length; i++) {
      if (i >= headerRow.length ||
          _normalizeHeader(headerRow[i]) != requiredHeaders[i]) {
        throw const FormatException(invalidFormatMessage);
      }
    }

    final summary = PreprocessSummary();
    final rawLogs = <Map<String, dynamic>>[];
    var punchCounter = 0;

    for (final row in rows.skip(1)) {
      final rowNumber = int.tryParse(row.getAttribute('r') ?? '') ?? 0;
      final cells = _readRow(row, sharedStrings);
      if (cells.every((value) => _cellText(value).trim().isEmpty)) {
        continue;
      }

      summary.excelRowsRead++;
      final biometricId = _cellText(_valueAt(cells, 0)).trim();
      final employeeName = _cellText(_valueAt(cells, 1)).trim();
      final workDate = parseExcelDate(_valueAt(cells, 2));
      final scheduledStart = _combineDateAndTime(workDate, _valueAt(cells, 3));
      var scheduledEnd = _combineDateAndTime(workDate, _valueAt(cells, 4));
      final actualCheckIn = _combineDateAndTime(workDate, _valueAt(cells, 5));
      var actualCheckOut = _combineDateAndTime(workDate, _valueAt(cells, 6));
      final isAbsent = _parseBool(_valueAt(cells, 9));

      if (biometricId.isEmpty || workDate == null) {
        rawLogs.add({
          'raw_line': 'Excel row $rowNumber',
          'is_valid': false,
          'error_message': 'لم يتمكن من استخراج رقم البصمة أو التاريخ',
        });
        summary.unmatchedEmployees++;
        continue;
      }

      DateTime? normalizedScheduledEnd = scheduledEnd;
      if (scheduledStart != null &&
          normalizedScheduledEnd != null &&
          !normalizedScheduledEnd.isAfter(scheduledStart)) {
        normalizedScheduledEnd = normalizedScheduledEnd.add(
          const Duration(days: 1),
        );
      }

      DateTime? normalizedActualCheckOut = actualCheckOut;
      if (actualCheckIn != null &&
          normalizedActualCheckOut != null &&
          normalizedActualCheckOut.isBefore(actualCheckIn)) {
        normalizedActualCheckOut = normalizedActualCheckOut.add(
          const Duration(days: 1),
        );
      }

      final punches = <BiometricPunch>[];
      if (actualCheckIn != null) {
        punches.add(
          BiometricPunch(
            id: 'excel_${punchCounter++}',
            biometricId: biometricId,
            time: actualCheckIn,
            isValid: true,
            role: PunchRole.checkIn,
          ),
        );
        summary.usedCheckIns++;
        rawLogs.add(
          _rawLog(
            biometricId: biometricId,
            employeeName: employeeName,
            punchTime: actualCheckIn,
            punchType: 'check_in',
            rowNumber: rowNumber,
          ),
        );
      }

      if (normalizedActualCheckOut != null) {
        punches.add(
          BiometricPunch(
            id: 'excel_${punchCounter++}',
            biometricId: biometricId,
            time: normalizedActualCheckOut,
            isValid: true,
            role: PunchRole.checkOut,
          ),
        );
        summary.usedCheckOuts++;
        rawLogs.add(
          _rawLog(
            biometricId: biometricId,
            employeeName: employeeName,
            punchTime: normalizedActualCheckOut,
            punchType: 'check_out',
            rowNumber: rowNumber,
          ),
        );
      }

      final group =
          ProcessedGroup(
              biometricId: biometricId,
              physicalDate: workDate,
              punches: punches,
              employeeName: employeeName.isEmpty ? null : employeeName,
              sourceRowNumber: rowNumber,
            )
            ..workDate = DateTime(workDate.year, workDate.month, workDate.day)
            ..shiftStart = scheduledStart
            ..shiftEnd = normalizedScheduledEnd
            ..actualCheckIn = actualCheckIn
            ..actualCheckOut = normalizedActualCheckOut
            ..suggestedShift = _shiftFromExcel(
              scheduledStart,
              normalizedScheduledEnd,
            );

      if (isAbsent &&
          actualCheckIn == null &&
          normalizedActualCheckOut == null) {
        group.isAbsent = true;
        group.reviewReason = 'غياب';
        summary.absentCases++;
      } else if (actualCheckIn != null && normalizedActualCheckOut == null) {
        group.needsReview = true;
        group.reviewReason = 'لم يتم العثور على بصمة خروج.';
        summary.needsReviewGroups++;
        summary.missingCheckOuts++;
      } else if (actualCheckIn == null && normalizedActualCheckOut != null) {
        group.needsReview = true;
        group.reviewReason = 'لم يتم العثور على بصمة دخول.';
        summary.needsReviewGroups++;
        summary.missingCheckIns++;
      } else if (actualCheckIn == null && normalizedActualCheckOut == null) {
        group.needsReview = true;
        group.reviewReason = 'لا توجد بصمة دخول أو خروج.';
        summary.needsReviewGroups++;
        summary.missingCheckIns++;
        summary.missingCheckOuts++;
      } else if (normalizedScheduledEnd != null) {
        final overtimeRaw = normalizedActualCheckOut!
            .difference(normalizedScheduledEnd)
            .inMinutes;
        if (overtimeRaw > BiometricPreprocessor.overtimeMinimumTriggerMinutes) {
          group.expectedOvertimeMinutes = overtimeRaw;
          summary.expectedOvertimeCases++;
        }
      }

      summary.groups.add(group);
    }

    summary.totalPunches = summary.excelRowsRead;
    summary.matchedEmployees = summary.groups
        .map((group) => group.biometricId)
        .toSet()
        .length;
    summary.groups.sort((a, b) {
      final dateCompare = a.workDate.compareTo(b.workDate);
      if (dateCompare != 0) return dateCompare;
      return a.biometricId.compareTo(b.biometricId);
    });

    return ExcelAttendanceImportResult(summary: summary, rawLogs: rawLogs);
  }

  static Map<String, dynamic> _rawLog({
    required String biometricId,
    required String employeeName,
    required DateTime punchTime,
    required String punchType,
    required int rowNumber,
  }) {
    return {
      'biometric_employee_id': biometricId,
      'punch_time': punchTime,
      'employee_name_from_device': employeeName.isEmpty ? null : employeeName,
      'punch_type': punchType,
      'raw_line': 'Excel row $rowNumber',
      'is_valid': true,
      'error_message': null,
    };
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];

    final document = XmlDocument.parse(_fileText(file));
    return document
        .findAllElements('si')
        .map(
          (si) => si.findAllElements('t').map((text) => text.innerText).join(),
        )
        .toList();
  }

  static String _firstSheetPath(Archive archive) {
    final workbookFile = archive.findFile('xl/workbook.xml');
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    if (workbookFile == null || relsFile == null) {
      return 'xl/worksheets/sheet1.xml';
    }

    final workbook = XmlDocument.parse(_fileText(workbookFile));
    final firstSheet = _firstOrNull(workbook.findAllElements('sheet'));
    final relId =
        firstSheet?.getAttribute('r:id') ?? firstSheet?.getAttribute('id');
    if (relId == null) return 'xl/worksheets/sheet1.xml';

    final rels = XmlDocument.parse(_fileText(relsFile));
    for (final rel in rels.findAllElements('Relationship')) {
      if (rel.getAttribute('Id') == relId) {
        final target = rel.getAttribute('Target');
        if (target == null) break;
        return target.startsWith('xl/') ? target : 'xl/$target';
      }
    }

    return 'xl/worksheets/sheet1.xml';
  }

  static List<Object?> _readRow(XmlElement row, List<String> sharedStrings) {
    final values = <Object?>[];
    for (final cell in row.findElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      final columnIndex = _columnIndex(ref);
      while (values.length <= columnIndex) {
        values.add(null);
      }
      values[columnIndex] = _readCell(cell, sharedStrings);
    }
    return values;
  }

  static Object? _readCell(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    final rawValue = _firstOrNull(cell.findElements('v'))?.innerText;
    if (rawValue == null) return null;

    if (type == 's') {
      final index = int.tryParse(rawValue);
      if (index != null && index >= 0 && index < sharedStrings.length) {
        return sharedStrings[index];
      }
      return '';
    }

    if (type == 'b') {
      return rawValue == '1';
    }

    return double.tryParse(rawValue) ?? rawValue;
  }

  static int _columnIndex(String cellRef) {
    var index = 0;
    for (final codeUnit in cellRef.codeUnits) {
      if (codeUnit < 65 || codeUnit > 90) break;
      index = index * 26 + (codeUnit - 64);
    }
    return math.max(0, index - 1);
  }

  static Object? _valueAt(List<Object?> cells, int index) {
    return index < cells.length ? cells[index] : null;
  }

  static String _cellText(Object? value) {
    if (value == null) return '';
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is num && value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }

  static String _normalizeHeader(Object? value) => _cellText(value).trim();

  static DateTime? parseExcelDate(Object? value) {
    if (value == null) return null;

    // Excel serial number
    if (value is num) {
      return DateTime(1899, 12, 30).add(Duration(days: value.floor()));
    }

    // Excel DateTime object (if any platform-specific parse handles it)
    if (value is DateTime) {
      return value;
    }

    final text = _cellText(value).trim();
    if (text.isEmpty) return null;

    // DD/MM/YYYY or DD/MM/YY or D/M/YYYY
    final match = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+.*)?$',
    ).firstMatch(text);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }

    // Do NOT fallback to DateTime.tryParse as requested by user
    return null;
  }

  static DateTime? _combineDateAndTime(DateTime? date, Object? value) {
    if (date == null || value == null) return null;
    final minutes = _parseTimeMinutes(value);
    if (minutes == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minutes));
  }

  static int? _parseTimeMinutes(Object? value) {
    if (value == null) return null;
    if (value is num) {
      final fraction = value - value.floor();
      return (fraction * 24 * 60).round();
    }

    final text = _cellText(value).trim();
    if (text.isEmpty) return null;

    final timeMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(text);
    if (timeMatch != null) {
      return int.parse(timeMatch.group(1)!) * 60 +
          int.parse(timeMatch.group(2)!);
    }

    final number = double.tryParse(text);
    if (number != null) {
      return ((number - number.floor()) * 24 * 60).round();
    }

    final parsedDate = DateTime.tryParse(text);
    if (parsedDate != null) {
      return parsedDate.hour * 60 + parsedDate.minute;
    }

    return null;
  }

  static bool _parseBool(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = _cellText(value).trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == 'نعم';
  }

  static ShiftDefinition? _shiftFromExcel(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    return ShiftDefinition(
      id: 'excel_${start.hour}_${end.hour}',
      name:
          'Excel ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      startHour: start.hour,
      endHour: end.hour,
      windowStartHour: start.hour,
      windowEndHour: end.hour,
    );
  }

  static String _fileText(ArchiveFile file) {
    return utf8.decode(List<int>.from(file.content));
  }

  static T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
