import 'dart:convert';
import 'dart:typed_data';

class BiometricImportService {
  static List<Map<String, dynamic>> parseFile(
    Uint8List bytes,
    String encoding,
  ) {
    String content;

    // Attempt decoding based on requested encoding
    if (encoding == 'Windows-1256') {
      try {
        content = latin1.decode(bytes, allowInvalid: true);
      } catch (e) {
        content = utf8.decode(bytes, allowMalformed: true);
      }
    } else {
      content = utf8.decode(bytes, allowMalformed: true);
    }

    final lines = content.split('\n');
    final results = <Map<String, dynamic>>[];

    // Typical ZKTeco formats:
    // [Emp No] \t [Date Time] \t ...
    // OR space separated if exported weirdly
    final dateRegex = RegExp(r'\d{4}[-/]\d{2}[-/]\d{2}\s\d{2}:\d{2}:\d{2}');

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      var parts = line.split('\t');
      if (parts.length < 2) {
        parts = line.split(RegExp(r'\s{2,}'));
      }
      if (parts.length < 2) {
        parts = line.split(RegExp(r'\s+'));
      }

      if (parts.length >= 2) {
        final biometricId = parts[0].trim();

        String? dateTimeStr;

        // Search for a date time pattern in the parts
        for (var p in parts) {
          if (dateRegex.hasMatch(p)) {
            dateTimeStr = dateRegex.stringMatch(p);
            break;
          }
        }

        // If not found in a single part, try combining parts 1 and 2 (Date and Time might be separated by space)
        if (dateTimeStr == null && parts.length >= 3) {
          final possibleDate = "${parts[1]} ${parts[2]}".trim();
          if (dateRegex.hasMatch(possibleDate)) {
            dateTimeStr = dateRegex.stringMatch(possibleDate);
          }
        }

        if (dateTimeStr == null) {
          // fallback, maybe it's just parts[1]
          dateTimeStr = parts[1].trim();
        }

        DateTime? punchTime;
        try {
          // Replace slashes with dashes if needed
          String normalizedDate = dateTimeStr!.replaceAll('/', '-');
          punchTime = DateTime.parse(normalizedDate);
        } catch (e) {
          // Invalid date format
        }

        if (punchTime != null) {
          results.add({
            'biometric_employee_id': biometricId,
            'punch_time': punchTime,
            'employee_name_from_device': parts.length > 3
                ? parts[3].trim()
                : null,
            'punch_type': parts.length > 4 ? parts[4].trim() : null,
            'raw_line': line.trim(),
            'is_valid': true,
            'error_message': null,
          });
          continue;
        }
      }

      results.add({
        'raw_line': line.trim(),
        'is_valid': false,
        'error_message': 'لم يتمكن من استخراج رقم البصمة أو التاريخ/الوقت',
      });
    }

    return results;
  }
}
