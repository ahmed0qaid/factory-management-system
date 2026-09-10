import 'package:dart_appwrite/dart_appwrite.dart';
import '../lib/config/constants.dart';
import 'dart:io';
import 'setup_db.dart';

Future<void> main() async {
  var endpoint = Platform.environment['APPWRITE_ENDPOINT'];
  var projectId = Platform.environment['APPWRITE_PROJECT_ID'];
  var apiKey = Platform.environment['APPWRITE_API_KEY'];
  var databaseId = Platform.environment['APPWRITE_DATABASE_ID'];

  if (endpoint == null) {
    try {
      final env = File('.env').readAsStringSync();
      for (var line in env.split('\n')) {
        if (line.startsWith('APPWRITE_ENDPOINT='))
          endpoint = line.split('=')[1].trim();
        if (line.startsWith('APPWRITE_PROJECT_ID='))
          projectId = line.split('=')[1].trim();
        if (line.startsWith('APPWRITE_API_KEY='))
          apiKey = line.split('=')[1].trim();
        if (line.startsWith('APPWRITE_DATABASE_ID='))
          databaseId = line.split('=')[1].trim();
      }
    } catch (e) {
      print('Could not read .env file');
    }
  }

  if (endpoint == null ||
      projectId == null ||
      apiKey == null ||
      databaseId == null) {
    print('Missing Appwrite environment variables.');
    exit(1);
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);

  final tablesToUpdate = [
    AppConstants.profilesTable,
    AppConstants.payrollTable,
    AppConstants.advancesTable,
    AppConstants.leaveRequestsTable,
    AppConstants.penaltiesTable,
    AppConstants.attendanceTable,
    AppConstants.attendancePoliciesTable,
    AppConstants.biometricImportBatchesTable,
    AppConstants.biometricLogsTable,
    AppConstants.shiftsTable,
    AppConstants.employeeShiftAssignmentsTable,
    'overtime_records',
    'employee_documents',
  ];

  final adminPermissions = [
    Permission.read(Role.team('company_main', 'hr_admin')),
    Permission.create(Role.team('company_main', 'hr_admin')),
    Permission.update(Role.team('company_main', 'hr_admin')),
    Permission.delete(Role.team('company_main', 'hr_admin')),
    // Adding general read for company_main as it was in many tables, but focusing on hr_admin here.
    Permission.read(Role.team('company_main')),
  ];

  print('==========================================');
  print('Starting Permissions Fix for HR Admin...');
  print('==========================================');

  for (final table in tablesToUpdate) {
    try {
      // 1. Update Collection Permissions
      await db.updateCollection(
        databaseId: databaseId,
        collectionId: table,
        name: table,
        permissions: adminPermissions,
        documentSecurity: true,
      );
      print('[$table] Collection permissions updated.');

      // 2. Update Row Permissions
      int limit = 100;
      int offset = 0;
      bool hasMore = true;
      int updatedCount = 0;

      while (hasMore) {
        final docs = await db.listDocuments(
          databaseId: databaseId,
          collectionId: table,
          queries: [Query.limit(limit), Query.offset(offset)],
        );

        for (final doc in docs.documents) {
          final currentPerms = doc.$permissions;

          // Check if hr_admin read is missing
          bool needsUpdate = !currentPerms.any(
            (p) => p.contains('team:company_main/hr_admin'),
          );

          if (needsUpdate) {
            // Append hr_admin permissions to existing ones so we don't break user read access
            final newPerms = [
              ...currentPerms,
              Permission.read(Role.team('company_main', 'hr_admin')),
              Permission.update(Role.team('company_main', 'hr_admin')),
              Permission.delete(Role.team('company_main', 'hr_admin')),
            ].toSet().toList(); // Remove duplicates

            await db.updateDocument(
              databaseId: databaseId,
              collectionId: table,
              documentId: doc.$id,
              permissions: newPerms,
            );
            updatedCount++;
          }
        }

        if (docs.documents.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      print('[$table] Row permissions updated: $updatedCount rows.');
    } catch (e) {
      print('[$table] Error processing table: $e');
    }
  }

  print('==========================================');
  print('Permissions fix completed successfully.');
  print('==========================================');
}
