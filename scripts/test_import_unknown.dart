import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0]] = parts.sublist(1).join('=').trim().replaceAll("'", "");
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final apiKey = env['APPWRITE_API_KEY'];
  final databaseId = env['APPWRITE_DATABASE_ID'];

  if (projectId == null || apiKey == null || databaseId == null) {
    print('Missing Appwrite variables in .env');
    exit(1);
  }

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);

  final databases = Databases(client);

  try {
    print('Testing TMP_UNKNOWN_999 insertion...');
    final doc = await databases.createDocument(
      databaseId: databaseId,
      collectionId: 'temporary_biometric_employees',
      documentId: 'temp_TMP_UNKNOWN_999',
      data: {
        'company_id': 'company_main',
        'biometric_employee_id': 'TMP_UNKNOWN_999',
        'status': 'pending',
        'first_seen_at': DateTime.now().toIso8601String(),
        'last_seen_at': DateTime.now().toIso8601String(),
        'punches_count': 1,
      },
    );
    print('Created successfully: \${doc.\$id}');

    // Attempting to create again to test double counting prevention
    print('Attempting to create again to test idempotency...');
    try {
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'temporary_biometric_employees',
        documentId: 'temp_TMP_UNKNOWN_999',
        data: {
          'company_id': 'company_main',
          'biometric_employee_id': 'TMP_UNKNOWN_999',
          'status': 'pending',
          'first_seen_at': DateTime.now().toIso8601String(),
          'last_seen_at': DateTime.now().toIso8601String(),
          'punches_count': 1,
        },
      );
      print('FAILED: It allowed duplicate creation (bad).');
    } catch (e) {
      print('SUCCESS: Blocked duplicate creation as expected.');
    }
  } catch (e) {
    if (e is AppwriteException) {
      if (e.code == 409) {
        print(
          'Document already exists (409) - idempotency working if ran twice.',
        );
      } else {
        print(
          'Error: code: \${e.code}, type: \${e.type}, message: \${e.message}',
        );
      }
    } else {
      print('Error: \$e');
    }
  }
}
