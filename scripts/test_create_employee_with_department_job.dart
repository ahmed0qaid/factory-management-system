import 'dart:convert';
import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';

const employeeNumber = 'TEST_DEPT_JOB_002';
const fullName =
    '\u0645\u0648\u0638\u0641 \u0627\u062e\u062a\u0628\u0627\u0631 \u0642\u0633\u0645 \u0648\u0645\u0633\u0645\u0649';
const temporaryPassword = '12345678';
const role = 'employee';
const departmentName =
    '\u0627\u0644\u0645\u0648\u0627\u0631\u062f \u0627\u0644\u0628\u0634\u0631\u064a\u0629';
const jobTitleName = '\u0645\u062d\u0627\u0633\u0628';
const biometricEmployeeId = 'TEST_DEPT_JOB_BIO_002';
const phone = '+964770000002';
const baseSalary = 1000;
const monthlyBonus = 100;

Future<Map<String, String>> loadEnv() async {
  final env = <String, String>{};
  final file = File('.env');
  if (!await file.exists()) return env;

  for (final line in await file.readAsLines()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    var value = trimmed.substring(separator + 1).trim();
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1);
    }
    env[key] = value;
  }
  return env;
}

Future<Map<String, dynamic>?> findProfile(
  TablesDB tablesDB,
  String databaseId,
  String employeeNumber,
) async {
  final rows = await tablesDB
      .listRows(
        databaseId: databaseId,
        tableId: 'profiles',
        queries: [
          Query.equal('employee_number', employeeNumber),
          Query.limit(1),
        ],
      )
      .timeout(const Duration(seconds: 30));

  if (rows.rows.isEmpty) return null;
  return {...rows.rows.first.data, r'$id': rows.rows.first.$id};
}

Future<Map<String, dynamic>> request(
  HttpClient client,
  List<Cookie> cookies,
  String projectId,
  String method,
  String url, {
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.parse(url);
  final req = switch (method) {
    'POST' => await client.postUrl(uri),
    'GET' => await client.getUrl(uri),
    _ => throw ArgumentError('Unsupported method: $method'),
  };

  req.headers.set('x-appwrite-project', projectId);
  req.headers.set('content-type', 'application/json');
  for (final cookie in cookies) {
    req.cookies.add(cookie);
  }
  if (body != null) {
    req.write(jsonEncode(body));
  }

  final res = await req.close();
  for (final cookie in res.cookies) {
    cookies.removeWhere((existing) => existing.name == cookie.name);
    cookies.add(cookie);
  }

  final responseBody = await res.transform(utf8.decoder).join();
  return {
    'statusCode': res.statusCode,
    'body': responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody),
  };
}

void printProfileResult(
  Map<String, dynamic>? profile, {
  required bool created,
}) {
  if (profile == null) {
    print('created: false');
    print('found_in_profiles: false');
    return;
  }

  final savedDepartment = profile['department_name'];
  final savedJobTitle = profile['job_title_name'];
  final savedBiometric = profile['biometric_employee_id'];
  final listTitle = '${profile['employee_number']} - ${savedJobTitle ?? "-"}';

  print('created: $created');
  print('found_in_profiles: true');
  print('employee_number: ${profile['employee_number']}');
  print('full_name: ${profile['full_name']}');
  print('department_name: $savedDepartment');
  print('job_title_name: $savedJobTitle');
  print('biometric_employee_id: $savedBiometric');
  print('department_name_ok: ${savedDepartment == departmentName}');
  print('job_title_name_ok: ${savedJobTitle == jobTitleName}');
  print('biometric_employee_id_ok: ${savedBiometric == biometricEmployeeId}');
  print('official_list_title: $listTitle');
}

Future<void> main() async {
  final env = await loadEnv();
  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';
  final functionId =
      env['APPWRITE_CREATE_EMPLOYEE_FUNCTION_ID'] ?? 'create_employee';
  final apiKey = env['APPWRITE_API_KEY'];
  final hrPassword = env['HR001_PASSWORD'] ?? '12345678';

  if (projectId == null ||
      projectId.isEmpty ||
      apiKey == null ||
      apiKey.isEmpty) {
    print('error: missing Appwrite project/API configuration');
    exitCode = 1;
    return;
  }

  final serverClient = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);
  final tablesDB = TablesDB(serverClient);

  try {
    final existing = await findProfile(tablesDB, databaseId, employeeNumber);
    if (existing != null) {
      printProfileResult(existing, created: false);
      return;
    }

    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 30);
    final cookies = <Cookie>[];

    final login = await request(
      httpClient,
      cookies,
      projectId,
      'POST',
      '$endpoint/account/sessions/email',
      body: {'email': 'hr001@hr.local', 'password': hrPassword},
    ).timeout(const Duration(seconds: 45));
    if ((login['statusCode'] as int) >= 400) {
      print('created: false');
      print('error: HR001 login failed (${login['statusCode']})');
      exitCode = 1;
      return;
    }

    final executionPayload = jsonEncode({
      'employeeNumber': employeeNumber,
      'fullName': fullName,
      'temporaryPassword': temporaryPassword,
      'role': role,
      'departmentName': departmentName,
      'jobTitleName': jobTitleName,
      'biometricEmployeeId': biometricEmployeeId,
      'phone': phone,
      'baseSalary': baseSalary,
      'monthlyBonus': monthlyBonus,
    });

    final executionResult = await request(
      httpClient,
      cookies,
      projectId,
      'POST',
      '$endpoint/functions/$functionId/executions',
      body: {
        'body': executionPayload,
        'async': false,
        'path': '/',
        'method': 'POST',
      },
    ).timeout(const Duration(seconds: 60));

    if ((executionResult['statusCode'] as int) >= 400) {
      print('created: false');
      print('function_http_status: ${executionResult['statusCode']}');
      final body = executionResult['body'];
      if (body is Map && body['message'] != null) {
        print('function_error: ${body['message']}');
      }
      exitCode = 1;
      return;
    }

    final execution = executionResult['body'] as Map<String, dynamic>;
    final status = execution['status']?.toString() ?? '';
    if (status.toLowerCase() != 'completed') {
      print('created: false');
      print('function_status: $status');
      final errors = execution['errors']?.toString() ?? '';
      if (errors.isNotEmpty) {
        print('function_error: $errors');
      }
      exitCode = 1;
      return;
    }

    final response = jsonDecode(
      (execution['responseBody']?.toString().isEmpty ?? true)
          ? '{}'
          : execution['responseBody'].toString(),
    );
    if (response is Map && response['success'] != true) {
      print('created: false');
      print('function_success: false');
      print('function_error: ${response['error'] ?? 'unknown'}');
      exitCode = 1;
      return;
    }

    final profile = await findProfile(tablesDB, databaseId, employeeNumber);
    printProfileResult(profile, created: true);
  } catch (e) {
    print('created: false');
    print('error: $e');
    exitCode = 1;
  }
}
