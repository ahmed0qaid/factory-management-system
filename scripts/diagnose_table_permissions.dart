import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

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
  final apiKey = env['APPWRITE_API_KEY'];
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  if (projectId == null || apiKey == null) {
    print('Missing config');
    return;
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);

  try {
    final collection = await db.getCollection(
      databaseId: databaseId,
      collectionId: 'profiles',
    );
    print('=====================================');
    print('Profiles Collection Settings');
    print('=====================================');
    print('Document Security Enabled: \${collection.documentSecurity}');
    print('Collection Permissions: \${collection.\$permissions}');
  } catch (e) {
    print('Error: \$e');
  }
}
