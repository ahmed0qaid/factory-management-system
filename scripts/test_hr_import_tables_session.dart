import 'dart:io' as io;
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final envFile = io.File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2)
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
  }

  final endpoint = env['APPWRITE_ENDPOINT']!;
  final projectId = env['APPWRITE_PROJECT_ID']!;
  final databaseId = env['APPWRITE_DATABASE_ID']!;

  print('==================================================');
  print('1. Login as HR001');
  print('==================================================');

  final loginRes = await http.post(
    Uri.parse('$endpoint/account/sessions/email'),
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': projectId,
    },
    body: jsonEncode({'email': 'hr001@hr.local', 'password': '12345678'}),
  );

  if (loginRes.statusCode >= 400) {
    print('FAIL: Could not login. ${loginRes.body}');
    return;
  }

  final secret = jsonDecode(loginRes.body)['secret'];
  final cookieStr =
      'a_session_${projectId}=$secret; a_session_${projectId}_legacy=$secret';

  final headers = {
    'Content-Type': 'application/json',
    'X-Appwrite-Project': projectId,
    'Cookie': cookieStr,
    'X-Fallback-Cookies': cookieStr,
  };

  final tablesToTest = [
    'biometric_import_batches',
    'biometric_logs',
    'attendance_records',
    'overtime_records',
    'notifications',
    'temporary_biometric_employees',
  ];

  final testData = {
    'biometric_import_batches': {
      'company_id': 'company_main',
      'file_name': 'test_file.txt',
      'total_punches': 10,
      'matched_punches': 8,
      'needs_review_count': 0,
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    },
    'biometric_logs': {
      'company_id': 'company_main',
      'import_batch_id': 'TEST_BATCH',
      'biometric_employee_id': 'EMP999',
      'punch_time': DateTime.now().toIso8601String(),
      'raw_line': 'test line',
      'created_at': DateTime.now().toIso8601String(),
    },
    'attendance_records': {
      'company_id': 'company_main',
      'employee_id': 'TEST_EMP',
      'employee_number': 'T001',
      'work_date': DateTime.now().toIso8601String(),
      'shift_start': DateTime.now().toIso8601String(),
      'shift_end': DateTime.now().toIso8601String(),
      'status': 'present',
    },
    'overtime_records': {
      'company_id': 'company_main',
      'employee_id': 'TEST_EMP',
      'work_date': DateTime.now().toIso8601String(),
      'overtime_minutes': 60,
      'approval_status': 'pending',
    },
    'notifications': {
      'user_id': 'TEST_EMP',
      'title': 'Test Notification',
      'message': 'This is a test',
      'type': 'system',
      'read': false,
      'created_at': DateTime.now().toIso8601String(),
    },
    'temporary_biometric_employees': {
      'company_id': 'company_main',
      'biometric_employee_id': 'TMP001',
      'status': 'pending',
      'punches_count': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
  };

  for (var table in tablesToTest) {
    print('\\n==================================================');
    print('Testing Table: $table');
    print('==================================================');

    // Create
    final createRes = await http.post(
      Uri.parse('$endpoint/databases/$databaseId/collections/$table/documents'),
      headers: headers,
      body: jsonEncode({'documentId': 'unique()', 'data': testData[table]}),
    );

    String? createdDocId;
    if (createRes.statusCode >= 400) {
      print('CREATE FAIL [HTTP ${createRes.statusCode}] - ${createRes.body}');
    } else {
      createdDocId = jsonDecode(createRes.body)['\$id'];
      print('CREATE SUCCESS ($createdDocId)');
    }

    // Read
    final readRes = await http.get(
      Uri.parse(
        '$endpoint/databases/$databaseId/collections/$table/documents?queries[]=limit(1)',
      ),
      headers: headers,
    );
    if (readRes.statusCode >= 400) {
      print('READ FAIL [HTTP ${readRes.statusCode}] - ${readRes.body}');
    } else {
      print('READ SUCCESS');
    }

    // Delete if created
    if (createdDocId != null) {
      await http.delete(
        Uri.parse(
          '$endpoint/databases/$databaseId/collections/$table/documents/$createdDocId',
        ),
        headers: headers,
      );
      print('CLEANUP SUCCESS');
    }
  }
}
