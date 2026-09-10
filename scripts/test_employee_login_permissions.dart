import 'dart:convert';
import 'dart:io';

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found.');
    return;
  }
  
  final envLines = envFile.readAsLinesSync();
  final env = <String, String>{};
  for (var line in envLines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT']!;
  final projectId = env['APPWRITE_PROJECT_ID']!;
  final dbId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  Future<void> testUser(String name, String email, String password, String profileId) async {
    print('\n==================================================');
    print('اختبار $name');
    print('==================================================');
    
    var loginReq = await HttpClient().postUrl(Uri.parse('$endpoint/account/sessions/email'));
    loginReq.headers.add('X-Appwrite-Project', projectId);
    loginReq.headers.add('Content-Type', 'application/json');
    loginReq.write(jsonEncode({'email': email, 'password': password}));
    var loginRes = await loginReq.close();
    var loginBody = await loginRes.transform(utf8.decoder).join();
    
    if (loginRes.statusCode >= 400) {
      print('-> فشل تسجيل الدخول: $loginBody');
      return;
    }
    
    final sessionCookie = loginRes.cookies.map((c) => '${c.name}=${c.value}').join('; ');
    print('-> نجح تسجيل الدخول.');
    
    var reqProfile = await HttpClient().getUrl(Uri.parse('$endpoint/databases/$dbId/collections/profiles/documents/$profileId'));
    reqProfile.headers.add('X-Appwrite-Project', projectId);
    reqProfile.headers.add('Cookie', sessionCookie);
    var resProfile = await reqProfile.close();
    var profileBody = await resProfile.transform(utf8.decoder).join();
    
    if (resProfile.statusCode >= 400) {
      print('-> فشل قراءة Profile: $profileBody');
    } else {
      print('-> نجحت قراءة Profile!');
    }
  }

  await testUser('HR001', 'hr001@hr.local', '12345678', '6a6a82992768c1b916cb');
  await testUser('الموظف 9', '9@hr.local', 'password123', '6a71b9690026efc8c835');
}
