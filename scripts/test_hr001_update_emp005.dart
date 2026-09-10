import 'dart:io';
import 'dart:convert';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  if (projectId == null) {
    print('Missing config');
    return;
  }

  print('=====================================');
  print('HR001 Session Test (REST API)');
  print('=====================================');

  final client = HttpClient();

  try {
    print('Attempting login as hr001@hr.local...');
    final loginReq = await client.postUrl(
      Uri.parse('$endpoint/account/sessions/email'),
    );
    loginReq.headers.add('X-Appwrite-Project', projectId);
    loginReq.headers.add('Content-Type', 'application/json');
    // Spoof client user agent so it accepts session creation
    loginReq.headers.add('User-Agent', 'appwrite-flutter/1.0.0');

    loginReq.write(
      jsonEncode({'email': 'hr001@hr.local', 'password': 'password123'}),
    );

    var loginRes = await loginReq.close();
    var loginBody = await loginRes.transform(utf8.decoder).join();

    if (loginRes.statusCode != 201) {
      // Try alternative password
      final loginReq2 = await client.postUrl(
        Uri.parse('$endpoint/account/sessions/email'),
      );
      loginReq2.headers.add('X-Appwrite-Project', projectId);
      loginReq2.headers.add('Content-Type', 'application/json');
      loginReq2.headers.add('User-Agent', 'appwrite-flutter/1.0.0');
      loginReq2.write(
        jsonEncode({'email': 'hr001@hr.local', 'password': '12345678'}),
      );
      loginRes = await loginReq2.close();
      loginBody = await loginRes.transform(utf8.decoder).join();

      if (loginRes.statusCode != 201) {
        print('Login failed! Status: ${loginRes.statusCode}, Body: $loginBody');
        return;
      }
    }

    final sessionData = jsonDecode(loginBody);
    final secret = sessionData['secret'];

    // Extract cookies
    final cookies = loginRes.headers['set-cookie'];
    String cookieStr = '';
    if (cookies != null) {
      cookieStr = cookies.join('; ');
    } else {
      cookieStr = 'a_session_$projectId=$secret';
    }

    print('Login successful.');

    final empId = '6a6b4dd5000d72682563'; // EMP005

    print('Attempting to update biometric_employee_id to 40...');
    final patchReq = await client.patchUrl(
      Uri.parse(
        '$endpoint/databases/$databaseId/collections/profiles/documents/$empId',
      ),
    );
    patchReq.headers.add('X-Appwrite-Project', projectId);
    patchReq.headers.add('X-Appwrite-Session', secret); // Try session header
    patchReq.headers.add('Cookie', cookieStr); // Try cookie header
    patchReq.headers.add('Content-Type', 'application/json');
    patchReq.headers.add('User-Agent', 'appwrite-flutter/1.0.0');

    patchReq.write(
      jsonEncode({
        'data': {'biometric_employee_id': '40'},
      }),
    );

    final patchRes = await patchReq.close();
    final patchBody = await patchRes.transform(utf8.decoder).join();

    if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
      print('HR001 can update EMP005 successfully');
      final updatedData = jsonDecode(patchBody);
      print(
        'saved biometric_employee_id = ' +
            updatedData['biometric_employee_id'].toString(),
      );
    } else {
      print('Update Failed!');
      print('status code: ${patchRes.statusCode}');
      print('message: $patchBody');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
