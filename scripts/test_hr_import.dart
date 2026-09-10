import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  print('====================================');
  print('Testing Import as HR001');
  print('====================================');

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

  final endpoint = env['APPWRITE_ENDPOINT']!;
  final projectId = env['APPWRITE_PROJECT_ID']!;
  final dbId = env['APPWRITE_DATABASE_ID']!;

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId);

  final account = Account(client);

  try {
    // 1. Login as HR001
    await account.createEmailPasswordSession(
      email: 'hr001@hr.local',
      password: 'password123',
    );
    print('SUCCESS: Logged in as HR001');

    final databases = Databases(client);

    // Get companyId for hr_admin (assuming HR001 is in company_main)
    final companyId = 'company_main';

    // Fetch emp005 profile id just to know
    final profiles = await databases.listDocuments(
      databaseId: dbId,
      collectionId: 'profiles',
      queries: [Query.equal('biometric_employee_id', 40)],
    );
    String emp005Id = '';
    if (profiles.documents.isNotEmpty) {
      emp005Id = profiles.documents.first.$id;
      print('EMP005 ID: $emp005Id');
    }

    // Now test importing a dummy file (simulate what preprocessor gives)
    // The problem is we can't easily run BiometricPreprocessor from a pure dart script without flutter dependencies if it uses Flutter (wait, we removed them!).
    // Actually we don't need to simulate the UI, we can just check if we can insert an attendance record.

    final attId = ID.unique();
    await databases.createDocument(
      databaseId: dbId,
      collectionId: 'attendance_records',
      documentId: attId,
      data: {
        'company_id': companyId,
        'employee_id': emp005Id,
        'work_date': '2026-07-31',
        'status': 'present',
      },
      permissions: [Permission.read(Role.any())],
    );
    print('SUCCESS: Created attendance record as HR001');
  } on AppwriteException catch (e) {
    print('ERROR (${e.code}): ${e.message}');
  } catch (e) {
    print('ERROR: $e');
  }
}
