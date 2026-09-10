import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

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

  final client = Client()
    .setEndpoint(env['APPWRITE_ENDPOINT']!)
    .setProject(env['APPWRITE_PROJECT_ID']!)
    .setKey(env['APPWRITE_API_KEY']!);

  final db = Databases(client);
  final users = Users(client);
  final dbId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  print('==================================================');
  print('1. فحص جدول profiles والمستخدم');
  print('==================================================');

  final docId = '6a71b9690026efc8c835';
  Map<String, dynamic> profile;
  List<String> permissions;
  try {
    final doc = await db.getDocument(
      databaseId: dbId,
      collectionId: 'profiles',
      documentId: docId,
    );
    profile = doc.data;
    permissions = doc.$permissions.cast<String>();
    print('-> تم العثور على الموظف في profiles.');
    print("   - employee_number: ${profile['employee_number']}");
    print("   - profile rowId: $docId");
  } catch (e) {
    print("-> فشل العثور على الوثيقة في profiles: $e");
    return;
  }

  print('\n==================================================');
  print('2. فحص Auth للمستخدم');
  print('==================================================');
  String? authEmail;
  try {
    final user = await users.get(userId: docId);
    authEmail = user.email;
    print('-> تم العثور على Auth User.');
    print("   - userId: ${user.$id}");
    print("   - email: $authEmail");
    print("   - هل profile rowId = userId؟ ${docId == user.$id ? 'نعم' : 'لا'}");
  } catch (e) {
    print("-> فشل العثور على المستخدم في Auth: $e");
  }

  print('\n==================================================');
  print('3. فحص Permissions للوثيقة (Profile)');
  print('==================================================');
  print('-> الصلاحيات الحالية:');
  for (var p in permissions) {
    print("   - $p");
  }

  print('\n==================================================');
  print('4. مقارنة مع HR001');
  print('==================================================');
  try {
    final hrDoc = await db.getDocument(
      databaseId: dbId,
      collectionId: 'profiles',
      documentId: '6a6a82992768c1b916cb',
    );
    print('-> HR001:');
    print("   - role: ${hrDoc.data['role']}");
    print("   - company_id: ${hrDoc.data['company_id']}");
    print("   - permissions: ${hrDoc.$permissions}");
  } catch(e) {
    print("-> فشل جلب بيانات HR001: $e");
  }
}
