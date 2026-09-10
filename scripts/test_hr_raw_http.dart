import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final envFile = File('.env');
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
  print('1. تسجيل الدخول كـ HR001');
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
    print('FAIL: Could not login as HR001. ${loginRes.body}');
    return;
  }

  print('SUCCESS: Logged in as HR001');

  // Extract cookie from Set-Cookie header
  final setCookie = loginRes.headers['set-cookie'];
  String? sessionCookie;
  if (setCookie != null) {
    sessionCookie = setCookie
        .split(';')
        .firstWhere((s) => s.contains('a_session_'), orElse: () => '');
  }
  if (sessionCookie == null || sessionCookie.isEmpty) {
    // If running on localhost, Appwrite might not send Set-Cookie if secure is true?
    // Let's manually construct it using the secret from the response
    final body = jsonDecode(loginRes.body);
    sessionCookie = "a_session_hr_employee_system_legacy=${body['secret']}";
    // Actually Appwrite uses legacy cookies for non-HTTPS sometimes
  }

  // Just take the secret and construct both
  final secret = jsonDecode(loginRes.body)['secret'];
  final cookieStr =
      'a_session_${projectId}=$secret; a_session_${projectId}_legacy=$secret';

  final headers = {
    'Content-Type': 'application/json',
    'X-Appwrite-Project': projectId,
    'Cookie': cookieStr,
    'X-Fallback-Cookies': cookieStr,
  };

  final tmpTestId = 'TMP_TEST_999';
  final tableId = 'temporary_biometric_employees';

  print('\n==================================================');
  print('2. اختبار إنشاء موظف مؤقت تجريبي ($tmpTestId)');
  print('==================================================');

  final createRes = await http.post(
    Uri.parse('$endpoint/databases/$databaseId/collections/$tableId/documents'),
    headers: headers,
    body: jsonEncode({
      'documentId': 'unique()',
      'data': {
        'company_id': 'company_main',
        'biometric_employee_id': tmpTestId,
        'status': 'pending',
        'punches_count': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
    }),
  );

  String? createdDocId;
  if (createRes.statusCode >= 400) {
    print('create temporary: fail - ${createRes.body}');
    return;
  } else {
    createdDocId = jsonDecode(createRes.body)['\$id'];
    print('create temporary: success ($createdDocId)');
  }

  print('\n==================================================');
  print('3. اختبار قراءة الموظفين المؤقتين pending');
  print('==================================================');

  final readRes = await http.get(
    Uri.parse(
      '$endpoint/databases/$databaseId/collections/$tableId/documents?queries[]=equal("company_id", "company_main")&queries[]=equal("status", "pending")',
    ),
    headers: headers,
  );

  if (readRes.statusCode >= 400) {
    print('read pending: fail - ${readRes.body}');
  } else {
    final docs = jsonDecode(readRes.body)['documents'] as List;
    if (docs.any((d) => d['\$id'] == createdDocId)) {
      print('read pending: success');
    } else {
      print('read pending: fail (document not found)');
    }
  }

  print('\n==================================================');
  print('4. تحديث حالة TMP_TEST_999 من pending إلى rejected');
  print('==================================================');

  final rejectRes = await http.patch(
    Uri.parse(
      '$endpoint/databases/$databaseId/collections/$tableId/documents/$createdDocId',
    ),
    headers: headers,
    body: jsonEncode({
      'data': {
        'status': 'rejected',
        'rejected_at': DateTime.now().toIso8601String(),
      },
    }),
  );

  if (rejectRes.statusCode >= 400) {
    print('reject: fail - ${rejectRes.body}');
  } else {
    print('reject: success');
  }

  print('\n==================================================');
  print('5. إعادة فتحه إلى pending');
  print('==================================================');

  final reopenRes = await http.patch(
    Uri.parse(
      '$endpoint/databases/$databaseId/collections/$tableId/documents/$createdDocId',
    ),
    headers: headers,
    body: jsonEncode({
      'data': {'status': 'pending'},
    }),
  );

  if (reopenRes.statusCode >= 400) {
    print('reopen pending: fail - ${reopenRes.body}');
  } else {
    print('reopen pending: success');
  }

  print('\n==================================================');
  print('6. تحديثه إلى linked');
  print('==================================================');

  final linkRes = await http.patch(
    Uri.parse(
      '$endpoint/databases/$databaseId/collections/$tableId/documents/$createdDocId',
    ),
    headers: headers,
    body: jsonEncode({
      'data': {'status': 'linked', 'linked_profile_id': 'EMP005_ID_SIMULATION'},
    }),
  );

  if (linkRes.statusCode >= 400) {
    print('link: fail - ${linkRes.body}');
  } else {
    print('link: success');
  }

  print('\n==================================================');
  print('7. تنظيف البيانات (حذف السجل التجريبي)');
  print('==================================================');

  final deleteRes = await http.delete(
    Uri.parse(
      '$endpoint/databases/$databaseId/collections/$tableId/documents/$createdDocId',
    ),
    headers: headers,
  );

  if (deleteRes.statusCode >= 400) {
    print('Cleanup: fail - ${deleteRes.body}');
  } else {
    print('Cleanup: success');
  }
}
