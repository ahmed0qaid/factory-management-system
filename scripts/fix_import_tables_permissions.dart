import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart';
import 'dart:io' as io;

void main() async {
  final envFile = io.File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2)
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
  }

  final endpoint = env['APPWRITE_ENDPOINT']!;
  final projectId = env['APPWRITE_PROJECT_ID']!;
  final apiKey = env['APPWRITE_API_KEY']!;
  final databaseId = env['APPWRITE_DATABASE_ID']!;

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);

  final databases = Databases(client);

  final collections = [
    'biometric_import_batches',
    'biometric_logs',
    'attendance_records',
    'overtime_records',
    'notifications',
    'temporary_biometric_employees',
  ];

  for (var collId in collections) {
    try {
      final collection = await databases.getCollection(
        databaseId: databaseId,
        collectionId: collId,
      );

      final permissions = [
        Permission.read(Role.users()),
        Permission.create(Role.team('company_main', 'hr_admin')),
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
        // Keep existing non-role-specific permissions if needed, but this is safe override for HR.
        // Actually it's better to add hr_admin to existing permissions.
      ];

      final existing = collection.documentSecurity
          ? collection.$permissions
          : [];

      // We just overwrite with broad permissions for testing, combining users read, hr_admin full, company_main read/create.
      final newPermissions = [
        Permission.read(Role.team('company_main')),
        Permission.create(Role.team('company_main')),
        Permission.update(Role.team('company_main')),
        Permission.delete(Role.team('company_main')),
        Permission.create(Role.team('company_main', 'hr_admin')),
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
      ];

      await databases.updateCollection(
        databaseId: databaseId,
        collectionId: collId,
        name: collection.name,
        permissions: newPermissions,
      );
      print('Fixed permissions for \$collId');
    } catch (e) {
      print('Error on \$collId: \$e');
    }
  }
}
