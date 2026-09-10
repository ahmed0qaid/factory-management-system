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
  final tempCollection = 'temporary_biometric_employees';

  try {
    print('Fetching linked records...');
    final res = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: tempCollection,
      queries: [Query.equal('status', 'linked')],
    );

    print('Found ${res.total} linked records.');
    for (var doc in res.documents) {
      final linkedProfileId = doc.data['linked_profile_id'];
      if (linkedProfileId != null && linkedProfileId.toString().isNotEmpty) {
        print('Updating ${doc.$id} to approved.');
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: tempCollection,
          documentId: doc.$id,
          data: {'status': 'approved'},
        );
      } else {
        print('Updating ${doc.$id} to rejected.');
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: tempCollection,
          documentId: doc.$id,
          data: {
            'status': 'rejected',
            'notes': 'تم إلغاء حالة linked لأنها لم تعد مستخدمة في النظام.',
          },
        );
      }
    }
    print('Done.');
  } catch (e) {
    print('Error: $e');
  }
}
