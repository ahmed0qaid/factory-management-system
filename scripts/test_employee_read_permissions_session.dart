import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final email = '9@hr.local';
  final password = '12345678';
  final projectId = '6a6a49d1000884049205';
  final endpoint = 'https://fra.cloud.appwrite.io/v1';
  final databaseId = 'hr';

  // 1. Login
  print('Logging in as $email...');
  final loginResponse = await http.post(
    Uri.parse('$endpoint/account/sessions/email'),
    headers: {
      'Content-Type': 'application/json',
      'X-Appwrite-Project': projectId,
    },
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (loginResponse.statusCode >= 300) {
    print('Failed to login: ${loginResponse.body}');
    return;
  }
  
  final rawCookie = loginResponse.headers['set-cookie'] ?? '';
  final cookie = rawCookie.split(';')[0];
  print('Login successful. Session obtained.');

  // 2. Test tables
  final tables = [
    'profiles',
    'attendance_records',
    'advances',
    'penalties',
    'leave_requests',
    'factory_stoppages',
    'overtime_records',
    'payroll_records',
  ];

  print('\n--- Testing Read Permissions ---');
  for (final table in tables) {
    final response = await http.get(
      Uri.parse('$endpoint/databases/$databaseId/collections/$table/documents'),
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': projectId,
        'Cookie': cookie,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('table: $table | read success | status: ${response.statusCode} | message: OK');
    } else {
      var msg = '';
      try {
        msg = jsonDecode(response.body)['message'] ?? response.body;
      } catch (e) {
        msg = response.body;
      }
      print('table: $table | read fail | status: ${response.statusCode} | message: $msg');
    }
  }
}
