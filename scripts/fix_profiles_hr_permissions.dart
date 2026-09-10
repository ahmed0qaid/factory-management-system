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
    print('Missing Appwrite config');
    return;
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);
  final users = Users(client);
  final teams = Teams(client);

  print('--- Checking Teams & Memberships ---');
  try {
    final memberships = await teams.listMemberships(teamId: 'company_main');
    print('Total members in company_main: ${memberships.total}');
    bool foundHr001 = false;
    for (var m in memberships.memberships) {
      if (m.userEmail == 'hr@company.com' || m.userName.contains('HR001')) {
        // assuming hr@company.com or something
        print('Found HR001 in team. Roles: ${m.roles}');
        foundHr001 = true;
      } else {
        // Also check if any member has hr_admin role to print it out
        if (m.roles.contains('hr_admin')) {
          print('User with hr_admin: ${m.userEmail} (ID: ${m.userId})');
        }
      }
    }
  } catch (e) {
    print('Could not list team memberships: $e');
  }

  print('\n--- Fixing Profiles Permissions ---');
  try {
    final docs = await db.listDocuments(
      databaseId: databaseId,
      collectionId: 'profiles',
      queries: [Query.limit(100)],
    );

    print('Found ${docs.total} profiles. Updating permissions...');

    int updatedCount = 0;
    for (var doc in docs.documents) {
      // we want to maintain the user's read access
      final employeeId = doc.$id; // In this system, profile ID = user ID

      final permissions = [
        Permission.read(Role.user(employeeId)),
        Permission.read(Role.team('company_main')),
        Permission.update(
          Role.user(employeeId),
        ), // If needed for personal fields
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
      ];

      try {
        await db.updateDocument(
          databaseId: databaseId,
          collectionId: 'profiles',
          documentId: doc.$id,
          permissions: permissions,
        );
        updatedCount++;
      } catch (e) {
        print('Failed to update permissions for ${doc.$id}: $e');
      }
    }
    print('Successfully updated permissions for $updatedCount profiles.');
  } catch (e) {
    print('Error accessing profiles: $e');
  }
}
