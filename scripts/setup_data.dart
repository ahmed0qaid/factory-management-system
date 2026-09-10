// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as models;

// --------------- .env parser ---------------
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
  print('  HR Data Setup Script');
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

  final teams = Teams(client);
  final users = Users(client);
  final tablesDB = TablesDB(client);
  final storage = Storage(client);

  final teamId = 'company_main';
  final email = 'hr001@hr.local';
  final password = '12345678';
  final name = 'مسؤول الموارد البشرية';
  String userId = '';

  // --- Step 2: Create Team ---
  print('--- Step 2: Create Team ---');
  try {
    await teams.create(teamId: teamId, name: 'Company Main');
    print('[CREATED] Team: $teamId');
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      print('[EXISTS]  Team: $teamId');
    } else {
      print('[FAILED]  Team: ${e.message}');
    }
  }

  // --- Step 3: Create HR001 User ---
  print('\n--- Step 3: Create HR001 User ---');
  try {
    // Try finding the user first
    final userList = await users.list(search: email);
    if (userList.total > 0) {
      final user = userList.users.first;
      userId = user.$id;
      print('[EXISTS]  User: HR001 found with ID: $userId');
    } else {
      // User doesn't exist, create
      final user = await users.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      userId = user.$id;
      print('[CREATED] User: HR001 created with ID: $userId');
    }
  } catch (e) {
    print('[FAILED]  User: $e');
    exit(1);
  }

  // --- Step 4: Add HR001 to Team ---
  print('\n--- Step 4: Add HR001 to Team ---');
  try {
    await teams.createMembership(
      teamId: teamId,
      roles: ['hr_admin'],
      email: email,
      url:
          'http://localhost', // Required by Appwrite even if not used immediately
    );
    print('[ADDED]   HR001 added to team $teamId as hr_admin');
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      print('[EXISTS]  HR001 already in team $teamId');
    } else {
      print('[WARN]    Team Membership: ${e.message}');
    }
  }

  // --- Step 5 & 6: Create/Update Profile Row with Permissions ---
  print('\n--- Step 5 & 6: Profile Row for HR001 ---');
  final rowData = {
    'company_id': 'company_main',
    'employee_number': 'HR001',
    'full_name': 'مسؤول الموارد البشرية',
    'role': 'hr_admin',
    'phone': '',
    'photo_path': '',
    'department_id': '',
    'department_name': 'الموارد البشرية',
    'job_title_id': '',
    'job_title_name': 'مسؤول موارد بشرية',
    'base_salary': 0.0,
    'monthly_bonus': 0.0,
    'active': true,
    'must_change_password': false,
    'hire_date': '2026-07-30T00:00:00.000+00:00',
  };

  final permissions = [
    Permission.read(Role.user(userId)),
    Permission.update(Role.user(userId)),
    Permission.read(Role.team('company_main', 'hr_admin')),
    Permission.update(Role.team('company_main', 'hr_admin')),
    Permission.delete(Role.team('company_main', 'hr_admin')),
  ];

  try {
    // Try to get the row first
    await tablesDB.getRow(
      databaseId: databaseId,
      tableId: 'profiles',
      rowId: userId,
    );
    // Exists, so update it
    await tablesDB.updateRow(
      databaseId: databaseId,
      tableId: 'profiles',
      rowId: userId,
      data: rowData,
      permissions: permissions,
    );
    print('[UPDATED] Profile row for HR001 updated.');
  } on AppwriteException catch (e) {
    if (e.code == 404) {
      // Not found, create it
      try {
        await tablesDB.createRow(
          databaseId: databaseId,
          tableId: 'profiles',
          rowId: userId,
          data: rowData,
          permissions: permissions,
        );
        print('[CREATED] Profile row for HR001 created.');
      } catch (ce) {
        print('[FAILED]  Create Profile: $ce');
      }
    } else {
      print('[FAILED]  Get Profile: ${e.message}');
    }
  }

  // --- Step 7: Create Storage Bucket ---
  print('\n--- Step 7: Storage Bucket ---');
  final bucketId = 'employee_files';
  try {
    await storage.createBucket(
      bucketId: bucketId,
      name: 'Employee Files',
      permissions: [
        Permission.read(Role.team('company_main')),
        Permission.create(Role.team('company_main')),
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
      ],
      fileSecurity: true, // Only accessible according to permissions
    );
    print('[CREATED] Bucket: $bucketId');
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      print('[EXISTS]  Bucket: $bucketId');
    } else {
      print('[FAILED]  Bucket: ${e.message}');
    }
  }

  print('\n========================================');
  print('  Setup Complete!');
  print('========================================');
}
