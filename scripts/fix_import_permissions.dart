import 'package:dart_appwrite/dart_appwrite.dart';
import 'dart:io';

void main() async {
  print('====================================');
  print('Fixing Appwrite Permissions for Import Tables');
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
  final apiKey = env['APPWRITE_API_KEY']!;
  final dbId = env['APPWRITE_DATABASE_ID']!;

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final databases = Databases(client);

  final tables = [
    'attendance_records',
    'overtime_records',
    'biometric_logs',
    'biometric_import_batches',
    'notifications',
  ];

  final hrAdminRole = Role.team('company_main', 'hr_admin');

  for (var table in tables) {
    try {
      final collection = await databases.getCollection(
        databaseId: dbId,
        collectionId: table,
      );

      final currentPermissions = collection.$permissions;

      final neededPermissions = [
        Permission.read(hrAdminRole),
        Permission.create(hrAdminRole),
        Permission.update(hrAdminRole),
      ];

      bool changed = false;
      for (var p in neededPermissions) {
        if (!currentPermissions.contains(p)) {
          currentPermissions.add(p);
          changed = true;
        }
      }

      if (changed) {
        await databases.updateCollection(
          databaseId: dbId,
          collectionId: table,
          name: collection.name,
          permissions: currentPermissions,
          documentSecurity: true, // Keep Document Level Security if enabled
        );
        print('SUCCESS: Updated permissions for \$table');
      } else {
        print('INFO: Permissions already correct for \$table');
      }
    } on AppwriteException catch (e) {
      print('ERROR: Failed to update \$table. \${e.message}');
    }
  }
}
