import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' hide File;

void main() async {
  print('====================================');
  print('Test Temporary Biometric Employees with HR001 Session');
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

  // Create admin client for creating user session if needed
  final adminClient = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(env['APPWRITE_API_KEY']!);

  // We will simulate a login by using Account
  final hrClient = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId);

  final account = Account(hrClient);
  final databases = Databases(hrClient);
  final tableId = 'temporary_biometric_employees';

  try {
    // Login as HR001
    final session = await account.createEmailPasswordSession(
      email: 'hr001@hr.local',
      password: '12345678',
    );
    print('SUCCESS: Logged in as HR001');

    // 1. Create temporary employee
    print('Testing CREATE...');
    final tempId = ID.unique();
    final doc = await databases.createDocument(
      databaseId: dbId,
      collectionId: tableId,
      documentId: tempId,
      data: {
        'company_id': 'cmp_1',
        'biometric_employee_id': '999_TEST',
        'status': 'pending',
        'punches_count': 5,
        'created_at': DateTime.now().toIso8601String(),
      },
      permissions: [],
    );
    print('SUCCESS: Created temporary employee ${doc.$id}');

    // 2. Read temporary employees
    print('Testing READ...');
    final docs = await databases.listDocuments(
      databaseId: dbId,
      collectionId: tableId,
      queries: [Query.equal('biometric_employee_id', '999_TEST')],
    );
    print('SUCCESS: Found ${docs.documents.length} documents');

    // 3. Update status to rejected
    print('Testing UPDATE (pending -> rejected)...');
    await databases.updateDocument(
      databaseId: dbId,
      collectionId: tableId,
      documentId: tempId,
      data: {
        'status': 'rejected',
        'rejected_at': DateTime.now().toIso8601String(),
      },
    );
    print('SUCCESS: Updated status to rejected');

    // 4. Update status to linked
    print('Testing UPDATE (rejected -> linked)...');
    await databases.updateDocument(
      databaseId: dbId,
      collectionId: tableId,
      documentId: tempId,
      data: {
        'status': 'linked',
        'linked_profile_id': 'test_profile_id',
        'linked_at': DateTime.now().toIso8601String(),
      },
    );
    print('SUCCESS: Updated status to linked');

    // 5. Delete test document to clean up (optional)
    await databases.deleteDocument(
      databaseId: dbId,
      collectionId: tableId,
      documentId: tempId,
    );
    print('SUCCESS: Test cleanup completed');
  } catch (e) {
    print('ERROR: $e');
  }
}
