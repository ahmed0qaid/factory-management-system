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

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId!)
    ..setKey(apiKey!);

  final db = Databases(client);

  try {
    // Let's set EMP005 to read("any") and see if it can be found.
    final permissions = [
      Permission.read(Role.any()), // Temporarily grant anyone read
      Permission.update(Role.team('company_main', 'hr_admin')),
      Permission.update(Role.users()), // Temporarily test users
      Permission.read(Role.users()), // Temporarily test users
    ];

    print('Updating EMP005 permissions to test...');
    await db.updateDocument(
      databaseId: databaseId,
      collectionId: 'profiles',
      documentId: '6a6b4dd5000d72682563',
      permissions: permissions,
    );
    print('Updated EMP005. Try the HR001 test script again.');
  } catch (e) {
    print('Error: \$e');
  }
}
