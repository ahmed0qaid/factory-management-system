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
    print('Updating collection permissions to include all needed roles...');

    await db.updateCollection(
      databaseId: databaseId,
      collectionId: 'profiles',
      name: 'profiles',
      permissions: [
        Permission.read(Role.users()),
        Permission.read(Role.team('company_main')),
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
        // Allow users to update their own profiles
        Permission.update(Role.users()), // We can restrict at document level
      ],
      documentSecurity: true, // Keep RLS enabled
      enabled: true,
    );
    print('Collection permissions updated successfully.');
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
