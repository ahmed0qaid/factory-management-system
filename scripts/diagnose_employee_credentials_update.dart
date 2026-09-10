import 'dart:convert';
import 'dart:io';

void main() async {
  // Load .env variables
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
  final apiKey = env['APPWRITE_API_KEY']!;
  final dbId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  final headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
    'Content-Type': 'application/json',
  };

  // We test on employee emp009 (id: 6a71b9690026efc8c835)
  final profileId = '6a71b9690026efc8c835';

  print('==================================================');
  print('أولًا: تشخيص الحالة قبل التعديل');
  print('==================================================');

  // 1. Get Profile
  var reqProfile = await HttpClient().getUrl(Uri.parse('$endpoint/databases/$dbId/collections/profiles/documents/$profileId'));
  headers.forEach((k, v) => reqProfile.headers.add(k, v));
  var resProfile = await reqProfile.close();
  var profileBody = await resProfile.transform(utf8.decoder).join();
  var profileData = jsonDecode(profileBody);

  final oldEmployeeNumber = profileData['employee_number'];
  final oldMustChange = profileData['must_change_password'];

  // 2. Get Auth User
  // profile.$id is Auth user ID
  final userId = profileId;
  var reqUser = await HttpClient().getUrl(Uri.parse('$endpoint/users/$userId'));
  headers.forEach((k, v) => reqUser.headers.add(k, v));
  var resUser = await reqUser.close();
  var userBody = await resUser.transform(utf8.decoder).join();
  var userData = jsonDecode(userBody);

  final oldEmail = userData['email'];

  print('- profileId: $profileId');
  print('- طريقة الربط مع Auth: profile.\$id هو نفسه userId في Auth');
  print('- userId: $userId');
  print('- employee_number الحالي في profiles: $oldEmployeeNumber');
  print('- email الحالي في Auth: $oldEmail');
  print('- must_change_password الحالي: $oldMustChange');

  print('\n==================================================');
  print('ثانيًا: تنفيذ التعديل (محاكاة استدعاء Function)');
  print('==================================================');

  // Trigger function
  final functionId = 'update_employee_credentials';
  
  // We need to simulate HR Admin. But we are using API KEY to execute the function directly?
  // Executing function using Server SDK doesn't pass x-appwrite-user-id automatically.
  // Wait, if we execute function via Server SDK, we can pass headers using executions API? No.
  // We will test the function via HTTP execution and pass a custom header if possible.
  // Actually, let's just test it via logging in as HR Admin!
  
  // Log in as HR Admin to get session
  var loginReq = await HttpClient().postUrl(Uri.parse('$endpoint/account/sessions/email'));
  loginReq.headers.add('X-Appwrite-Project', projectId);
  loginReq.headers.add('Content-Type', 'application/json');
  loginReq.write(jsonEncode({'email': 'hr001@hr.local', 'password': '12345678'}));
  var loginRes = await loginReq.close();
  var loginBody = await loginRes.transform(utf8.decoder).join();
  var loginData = jsonDecode(loginBody);
  
  if (loginRes.statusCode >= 400) {
    print('Failed to login as HR Admin: $loginBody');
    return;
  }
  
  final sessionCookie = loginRes.cookies.map((c) => '${c.name}=${c.value}').join('; ');
  final newEmpNum = 'EMP009_NEW';
  final newPass = 'newpass12345';
  
  print('جارِ تعديل employee_number إلى $newEmpNum وكلمة مرور جديدة...');
  
  var execReq = await HttpClient().postUrl(Uri.parse('$endpoint/functions/$functionId/executions'));
  execReq.headers.add('X-Appwrite-Project', projectId);
  execReq.headers.add('Content-Type', 'application/json');
  execReq.headers.add('Cookie', sessionCookie);
  
  final payload = {
    'profileId': profileId,
    'newEmployeeNumber': newEmpNum,
    'newPassword': newPass,
    'mustChangePassword': true,
  };
  
  execReq.write(jsonEncode({'body': jsonEncode(payload), 'async': false}));
  var execRes = await execReq.close();
  var execBody = await execRes.transform(utf8.decoder).join();
  var execData = jsonDecode(execBody);
  
  if (execRes.statusCode >= 400) {
    print('Execution failed: $execBody');
    return;
  }
  
  print("Function Execution Result: ${execData['responseBody']}");
  
  print('\n==================================================');
  print('ثالثًا: إثبات التعديل الفعلي بعد القراءة من Appwrite');
  print('==================================================');

  // 1. Get Profile After
  reqProfile = await HttpClient().getUrl(Uri.parse('$endpoint/databases/$dbId/collections/profiles/documents/$profileId'));
  headers.forEach((k, v) => reqProfile.headers.add(k, v));
  resProfile = await reqProfile.close();
  profileBody = await resProfile.transform(utf8.decoder).join();
  profileData = jsonDecode(profileBody);

  final newEmployeeNumber = profileData['employee_number'];
  final newMustChange = profileData['must_change_password'];

  // 2. Get Auth User After
  reqUser = await HttpClient().getUrl(Uri.parse('$endpoint/users/$userId'));
  headers.forEach((k, v) => reqUser.headers.add(k, v));
  resUser = await reqUser.close();
  userBody = await resUser.transform(utf8.decoder).join();
  userData = jsonDecode(userBody);

  final newEmail = userData['email'];

  print('- employee_number بعد التعديل: $newEmployeeNumber');
  print('- email في Auth بعد التعديل: $newEmail');
  print('- must_change_password بعد التعديل: $newMustChange');

  print('\n==================================================');
  print('رابعًا: تجربة تسجيل الدخول بكلمة المرور الجديدة');
  print('==================================================');
  
  var loginTestReq = await HttpClient().postUrl(Uri.parse('$endpoint/account/sessions/email'));
  loginTestReq.headers.add('X-Appwrite-Project', projectId);
  loginTestReq.headers.add('Content-Type', 'application/json');
  loginTestReq.write(jsonEncode({'email': newEmail, 'password': newPass}));
  var loginTestRes = await loginTestReq.close();
  var loginTestBody = await loginTestRes.transform(utf8.decoder).join();
  var loginTestData = jsonDecode(loginTestBody);
  
  if (loginTestRes.statusCode < 400) {
    print('-> نجح تسجيل الدخول بكلمة المرور الجديدة!');
  } else {
    print('-> فشل تسجيل الدخول: $loginTestBody');
  }

  print('\n==================================================');
  print('خامسًا: منع الرقم المكرر');
  print('==================================================');
  
  print('محاولة تعديل employee_number إلى رقم الموارد البشرية HR001...');
  
  var dupExecReq = await HttpClient().postUrl(Uri.parse('$endpoint/functions/$functionId/executions'));
  dupExecReq.headers.add('X-Appwrite-Project', projectId);
  dupExecReq.headers.add('Content-Type', 'application/json');
  dupExecReq.headers.add('Cookie', sessionCookie);
  
  final dupPayload = {
    'profileId': profileId,
    'newEmployeeNumber': 'HR001', 
  };
  
  dupExecReq.write(jsonEncode({'body': jsonEncode(dupPayload), 'async': false}));
  var dupExecRes = await dupExecReq.close();
  var dupExecBody = await dupExecRes.transform(utf8.decoder).join();
  var dupExecData = jsonDecode(dupExecBody);
  
  print("Function Execution Result for duplicate: ${dupExecData['responseBody']}");
  
  exit(0);
}
