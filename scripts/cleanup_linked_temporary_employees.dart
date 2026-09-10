import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

void main(List<String> args) async {
  bool dryRun = true;
  if (args.contains('--execute')) {
    dryRun = false;
  }

  print('==================================================');
  print('Cleanup Linked Temporary Employees');
  print('Dry Run: \$dryRun');
  print('==================================================');

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
  final tempCollection = 'temporary_biometric_employees';

  try {
    print('Fetching records...');
    final res = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: tempCollection,
      queries: [Query.equal('status', 'linked')],
    );

    print('Found \${res.total} records with status = linked.');
    if (res.total == 0) {
      print('Nothing to do.');
      return;
    }

    for (var doc in res.documents) {
      print('- Record: ' + doc.$id);
      print("  Biometric ID: \${doc.data['biometric_employee_id']}");
      print("  Linked Profile ID: \${doc.data['linked_profile_id']}");

      if (!dryRun) {
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: tempCollection,
          documentId: doc.$id,
          data: {
            'status': 'rejected',
            'notes':
                'تم إلغاء حالة linked لأنها لم تعد مستخدمة في نظام الموظفين المؤقتين.',
          },
        );
        print('  -> Updated to rejected.');
      } else {
        print('  -> [Dry Run] Would update to rejected.');
      }
    }
    print('Done.');
  } catch (e) {
    print('Error: \$e');
  }
}
