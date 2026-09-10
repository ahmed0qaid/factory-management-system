import 'dart:io' as io;
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart';

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

  final projectId = env['APPWRITE_PROJECT_ID']!;
  final databaseId = env['APPWRITE_DATABASE_ID']!;

  final client = Client()
    ..setEndpoint(env['APPWRITE_ENDPOINT']!)
    ..setProject(projectId)
    ..setSelfSigned(status: true);

  final account = Account(client);
  final databases = Databases(client);

  print('==================================================');
  print('1. تسجيل الدخول كـ HR001');
  print('==================================================');

  late Session session;
  try {
    session = await account.createEmailPasswordSession(
      email: 'hr001@hr.local',
      password: 'password123',
    );
    print('SUCCESS: Logged in as HR001');
  } catch (e) {
    try {
      session = await account.createEmailPasswordSession(
        email: 'hr001@hr.local',
        password: '12345678',
      );
      print('SUCCESS: Logged in as HR001');
    } catch (e2) {
      print('FAIL: Could not login as HR001. $e2');
      return;
    }
  }

  // Magic: Pass the session secret as a cookie to act as the user in dart_appwrite
  client.addHeader(
    'X-Fallback-Cookies',
    'a_session_$projectId=${session.secret}',
  );

  // Also pass the fallback cookie string directly in the Cookie header just in case Appwrite 1.4 requires it
  client.addHeader('cookie', 'a_session_$projectId=${session.secret}');

  final tmpTestId = 'TMP_TEST_999';
  final tableId = 'temporary_biometric_employees';

  print('\n==================================================');
  print('2. اختبار إنشاء موظف مؤقت تجريبي ($tmpTestId)');
  print('==================================================');

  String? createdDocId;
  try {
    final doc = await databases.createDocument(
      databaseId: databaseId,
      collectionId: tableId,
      documentId: ID.unique(),
      data: {
        'company_id': 'company_main',
        'biometric_employee_id': tmpTestId,
        'status': 'pending',
        'punches_count': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [],
    );
    createdDocId = doc.$id;
    print('create temporary: success ($createdDocId)');
  } catch (e) {
    print('create temporary: fail - $e');
    return;
  }

  print('\n==================================================');
  print('3. اختبار قراءة الموظفين المؤقتين pending');
  print('==================================================');
  try {
    final list = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: tableId,
      queries: [
        Query.equal('company_id', 'company_main'),
        Query.equal('status', 'pending'),
      ],
    );
    if (list.documents.any((d) => d.$id == createdDocId)) {
      print('read pending: success');
    } else {
      print('read pending: fail (document not found in list)');
    }
  } catch (e) {
    print('read pending: fail - $e');
  }

  print('\n==================================================');
  print('4. تحديث حالة TMP_TEST_999 من pending إلى rejected');
  print('==================================================');
  try {
    await databases.updateDocument(
      databaseId: databaseId,
      collectionId: tableId,
      documentId: createdDocId,
      data: {
        'status': 'rejected',
        'rejected_at': DateTime.now().toIso8601String(),
      },
    );
    print('reject: success');
  } catch (e) {
    print('reject: fail - $e');
  }

  try {
    final doc = await databases.getDocument(
      databaseId: databaseId,
      collectionId: tableId,
      documentId: createdDocId,
    );
    if (doc.data['status'] == 'rejected') {
      print('read rejected: success');
    }
  } catch (e) {}

  print('\n==================================================');
  print('5. إعادة فتحه إلى pending');
  print('==================================================');
  try {
    await databases.updateDocument(
      databaseId: databaseId,
      collectionId: tableId,
      documentId: createdDocId,
      data: {'status': 'pending'},
    );
    print('reopen pending: success');
  } catch (e) {
    print('reopen pending: fail - $e');
  }

  print('\n==================================================');
  print('6. تحديثه إلى linked');
  print('==================================================');
  try {
    await databases.updateDocument(
      databaseId: databaseId,
      collectionId: tableId,
      documentId: createdDocId,
      data: {'status': 'linked', 'linked_profile_id': 'EMP005_ID_SIMULATION'},
    );
    print('link: success');
  } catch (e) {
    print('link: fail - $e');
  }

  print('\n==================================================');
  print('7. تنظيف البيانات (حذف السجل التجريبي)');
  print('==================================================');
  try {
    await databases.deleteDocument(
      databaseId: databaseId,
      collectionId: tableId,
      documentId: createdDocId,
    );
    print('Cleanup: success');
  } catch (e) {
    print('Cleanup: fail - $e');
  }
}
