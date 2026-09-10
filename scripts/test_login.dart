// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart' as server;

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
  print('  HR Auth Diagnostic & Fix Script');
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

  // Server Client
  final srvClient = server.Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final srvUsers = server.Users(srvClient);
  final srvTeams = server.Teams(srvClient);
  final srvTablesDB = server.TablesDB(srvClient);

  final email = 'hr001@hr.local';
  final password = '12345678';
  final name = 'مسؤول الموارد البشرية';
  String userId = '';

  print('--- Step 3: Check User HR001 ---');
  try {
    final userList = await srvUsers.list(search: email);
    if (userList.total > 0) {
      final user = userList.users.first;
      userId = user.$id;
      print('[EXISTS]  User: HR001 found with ID: $userId');
      if (!user.status) {
        print('[INFO]    User is disabled. Enabling...');
        await srvUsers.updateStatus(userId: userId, status: true);
      }
      // Force update password to be sure
      print(
        '[INFO]    Updating password to 12345678 to ensure it is correct...',
      );
      await srvUsers.updatePassword(userId: userId, password: password);
      print('[UPDATED] Password reset successful.');
    } else {
      final user = await srvUsers.create(
        userId: server.ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      userId = user.$id;
      print('[CREATED] User: HR001 created with ID: $userId');
    }
  } catch (e) {
    print('[FAILED]  User Check: $e');
    exit(1);
  }

  print('\n--- Step 4: Check Profile Row ---');
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
    server.Permission.read(server.Role.user(userId)),
    server.Permission.update(server.Role.user(userId)),
    server.Permission.read(server.Role.team('company_main', 'hr_admin')),
    server.Permission.update(server.Role.team('company_main', 'hr_admin')),
    server.Permission.delete(server.Role.team('company_main', 'hr_admin')),
  ];

  try {
    await srvTablesDB.getRow(
      databaseId: databaseId,
      tableId: 'profiles',
      rowId: userId,
    );
    await srvTablesDB.updateRow(
      databaseId: databaseId,
      tableId: 'profiles',
      rowId: userId,
      data: rowData,
      permissions: permissions,
    );
    print('[UPDATED] Profile row updated with correct data and permissions.');
  } on server.AppwriteException catch (e) {
    if (e.code == 404) {
      try {
        await srvTablesDB.createRow(
          databaseId: databaseId,
          tableId: 'profiles',
          rowId: userId,
          data: rowData,
          permissions: permissions,
        );
        print('[CREATED] Profile row created.');
      } catch (ce) {
        print('[FAILED]  Create Profile: $ce');
      }
    } else {
      print('[FAILED]  Get Profile: ${e.message}');
    }
  }

  print('\n--- Step 5: Check Team Membership ---');
  try {
    await srvTeams.createMembership(
      teamId: 'company_main',
      roles: ['hr_admin'],
      email: email,
      url: 'http://localhost',
    );
    print('[ADDED]   HR001 added to team company_main as hr_admin');
  } on server.AppwriteException catch (e) {
    if (e.code == 409) {
      print('[EXISTS]  HR001 already in team company_main');
    } else {
      print('[WARN]    Team Membership: ${e.message}');
    }
  }

  print('\n--- Step 7: Fix All Tables Security ---');
  final expectedTables = [
    'profiles',
    'attendance_records',
    'penalties',
    'payroll_records',
    'advances',
    'announcements',
  ];

  for (final tid in expectedTables) {
    try {
      await srvTablesDB.updateTable(
        databaseId: databaseId,
        tableId: tid,
        rowSecurity: true, // Enable row-level permissions
        permissions: [
          server.Permission.read(server.Role.users()),
          server.Permission.create(server.Role.users()),
          server.Permission.update(server.Role.users()),
          server.Permission.delete(server.Role.users()),
        ],
      );
      print(
        '[SUCCESS] Table $tid updated with rowSecurity=true and users() permissions.',
      );
    } catch (e) {
      print('[FAILED] Table $tid Security: $e');
    }
  }

  print('\n--- Step 8: Test getRow via Server SDK ---');
  try {
    final row = await srvTablesDB.getRow(
      databaseId: databaseId,
      tableId: 'profiles',
      rowId: userId,
    );
    print(
      'Row fetched via Server SDK: employee_number=${row.data['employee_number']}, role=${row.data['role']}, must_change_password=${row.data['must_change_password']}',
    );
  } catch (e) {
    print('Failed to get row via Server SDK: $e');
  }

  print('\n========================================');
  print('  Diagnostics Complete!');
  print('========================================');
}
