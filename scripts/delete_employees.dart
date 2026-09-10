import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

Map<String, String> _parseEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    final key = trimmed.substring(0, idx).trim();
    final value = trimmed.substring(idx + 1).trim();
    env[key] = value;
  }
  return env;
}

Future<void> main() async {
  print('========================================');
  print('  Deleting Employees (except HR001)');
  print('========================================\n');

  final env = _parseEnvFile('.env');
  final endpoint = env['APPWRITE_ENDPOINT'] ?? '';
  final projectId = env['APPWRITE_PROJECT_ID'] ?? '';
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';
  final apiKey = env['APPWRITE_API_KEY'] ?? '';

  if (endpoint.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
    print('ERROR: Missing required environment variables.');
    exit(1);
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final users = Users(client);
  final tablesDB = TablesDB(client);

  print('Fetching Auth users...');
  final userList = await users.list();
  
  for (final user in userList.users) {
    if (user.email == 'hr001@hr.local' || user.name.contains('HR001')) {
      print('Skipping HR001 Auth User: ${user.email} (${user.$id})');
      continue;
    }

    // Try deleting profile doc first
    try {
      await tablesDB.deleteRow(
        databaseId: databaseId,
        tableId: 'profiles',
        rowId: user.$id,
      );
      print('Deleted Profile Doc: ${user.$id}');
    } catch (e) {
      // It might not have a profile, that's fine
    }

    // Delete Auth User
    try {
      await users.delete(userId: user.$id);
      print('Deleted Auth User: ${user.email} (${user.$id})');
    } catch (e) {
      print('Failed to delete Auth User ${user.email}: $e');
    }
  }

  print('\nFetching remaining Profile documents...');
  try {
    final profiles = await tablesDB.listRows(
      databaseId: databaseId,
      tableId: 'profiles',
      // Get up to 100 rows just in case
      queries: [Query.limit(100)],
    );
    for (final doc in profiles.rows) {
      final empNum = doc.data['employee_number']?.toString() ?? '';
      if (empNum.toUpperCase() == 'HR001') {
        print('Skipping HR001 Profile: ${doc.$id}');
        continue;
      }
      
      try {
        await tablesDB.deleteRow(
          databaseId: databaseId,
          tableId: 'profiles',
          rowId: doc.$id,
        );
        print('Deleted dangling Profile Doc: ${doc.$id} (Emp: $empNum)');
      } catch (e) {
        print('Failed to delete Profile Doc ${doc.$id}: $e');
      }
    }
  } catch (e) {
    print('Could not fetch profiles: $e');
  }

  print('\nDone.');
}
