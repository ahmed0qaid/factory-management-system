import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  print('====================================');
  print('Setup Temporary Biometric Employees Table');
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
  final tableName = 'temporary_biometric_employees';

  try {
    final hrAdminRole = Role.team('company_main', 'hr_admin');

    try {
      await databases.getCollection(databaseId: dbId, collectionId: tableName);
      print('INFO: Collection $tableName already exists.');
    } catch (e) {
      print('Creating collection $tableName...');
      await databases.createCollection(
        databaseId: dbId,
        collectionId: tableName,
        name: 'Temporary Biometric Employees',
        permissions: [
          Permission.read(hrAdminRole),
          Permission.create(hrAdminRole),
          Permission.update(hrAdminRole),
          Permission.delete(hrAdminRole),
        ],
        documentSecurity: false,
      );
      print('SUCCESS: Created collection $tableName');

      // Create Attributes
      print('Creating attributes...');
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'company_id',
        size: 50,
        xrequired: true,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'biometric_employee_id',
        size: 50,
        xrequired: true,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'employee_name_from_device',
        size: 180,
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'status',
        size: 20,
        xrequired: true,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'first_seen_at',
        xrequired: false,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'last_seen_at',
        xrequired: false,
      );
      await databases.createIntegerAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'punches_count',
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'source_batch_id',
        size: 50,
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'notes',
        size: 255,
        xrequired: false,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'created_at',
        xrequired: false,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'updated_at',
        xrequired: false,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'approved_at',
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'approved_by',
        size: 50,
        xrequired: false,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'rejected_at',
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'rejected_by',
        size: 50,
        xrequired: false,
      );
      await databases.createDatetimeAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'linked_at',
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'linked_by',
        size: 50,
        xrequired: false,
      );
      await databases.createStringAttribute(
        databaseId: dbId,
        collectionId: tableName,
        key: 'linked_profile_id',
        size: 50,
        xrequired: false,
      );

      print(
        'SUCCESS: All attributes initiated. Waiting for them to become available...',
      );
      await Future.delayed(const Duration(seconds: 5));
    }

    // Ensure permissions
    final collection = await databases.getCollection(
      databaseId: dbId,
      collectionId: tableName,
    );
    final currentPermissions = collection.$permissions;
    final neededPermissions = [
      Permission.read(hrAdminRole),
      Permission.create(hrAdminRole),
      Permission.update(hrAdminRole),
      Permission.delete(hrAdminRole),
    ];

    bool changed = false;
    for (var p in neededPermissions) {
      if (!currentPermissions.contains(p)) {
        currentPermissions.add(p);
        changed = true;
      }
    }

    // Force update to set documentSecurity false
    await databases.updateCollection(
      databaseId: dbId,
      collectionId: tableName,
      name: collection.name,
      permissions: neededPermissions,
      documentSecurity: false,
    );
    print('SUCCESS: Updated permissions and documentSecurity for $tableName');
  } on AppwriteException catch (e) {
    print('ERROR (${e.code}): ${e.message}');
  } catch (e) {
    print('ERROR: $e');
  }
}
