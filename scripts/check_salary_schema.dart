// ignore_for_file: avoid_print
// Read-only script to check salary-related schema in Appwrite.
// Does NOT modify any data or schema.

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
  print('  Salary Schema Check (READ ONLY)');
  print('========================================\n');

  final env = _parseEnvFile('.env');
  final endpoint = env['APPWRITE_ENDPOINT'] ?? '';
  final projectId = env['APPWRITE_PROJECT_ID'] ?? '';
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';
  final apiKey = env['APPWRITE_API_KEY'] ?? '';

  if (endpoint.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
    print('ERROR: Missing APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, or APPWRITE_API_KEY in .env');
    exit(1);
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final tablesDB = TablesDB(client);

  // Check profiles for daily_work_hours
  print('--- Checking profiles table ---');
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'profiles',
    );
    final salaryFields = [
      'base_salary',
      'monthly_bonus',
      'daily_work_hours',
      'active',
    ];
    final existingKeys = <String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        final key = (a.data as Map)['key']?.toString() ?? '';
        existingKeys.add(key);
      }
    }
    for (final field in salaryFields) {
      print(existingKeys.contains(field)
          ? '  [OK] $field exists'
          : '  [MISSING] $field');
    }
    print('  Total columns in profiles: ${cols.columns.length}');
  } catch (e) {
    print('  Error checking profiles: $e');
  }

  // Check payroll_records schema
  print('\n--- Checking payroll_records table ---');
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'payroll_records',
    );
    final existingKeys = <String, String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        final data = a.data as Map;
        final key = data['key']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'unknown';
        existingKeys[key] = type;
      }
    }
    print('  Columns found:');
    existingKeys.forEach((key, type) {
      print('    - $key ($type)');
    });
    print('  Total columns: ${cols.columns.length}');
  } catch (e) {
    print('  Error checking payroll_records: $e');
  }

  // Check penalties schema
  print('\n--- Checking penalties table ---');
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'penalties',
    );
    final existingKeys = <String, String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        final data = a.data as Map;
        final key = data['key']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'unknown';
        existingKeys[key] = type;
      }
    }
    print('  Columns found:');
    existingKeys.forEach((key, type) {
      print('    - $key ($type)');
    });
  } catch (e) {
    print('  Error checking penalties: $e');
  }

  // Check attendance_records schema
  print('\n--- Checking attendance_records table ---');
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'attendance_records',
    );
    final requiredFields = ['employee_id', 'work_date', 'status'];
    final existingKeys = <String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        existingKeys.add((a.data as Map)['key']?.toString() ?? '');
      }
    }
    for (final field in requiredFields) {
      print(existingKeys.contains(field)
          ? '  [OK] $field'
          : '  [MISSING] $field');
    }
  } catch (e) {
    print('  Error checking attendance_records: $e');
  }

  // Check advances schema
  print('\n--- Checking advances table ---');
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'advances',
    );
    final existingKeys = <String, String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        final data = a.data as Map;
        final key = data['key']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'unknown';
        existingKeys[key] = type;
      }
    }
    print('  Columns found:');
    existingKeys.forEach((key, type) {
      print('    - $key ($type)');
    });
  } catch (e) {
    print('  Error checking advances: $e');
  }

  print('\n========================================');
  print('  Check Complete (no changes made)');
  print('========================================');
}
