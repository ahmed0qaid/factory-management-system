// ignore_for_file: avoid_print
// ===========================================================
// setup_db.dart — Standalone Dart Server Script
// Creates the HR Database, Tables, Columns, and Indexes
// in Appwrite using the Server SDK (dart_appwrite) TablesDB API.
//
// Usage:  dart run setup_db.dart
//
// Reads configuration from .env (manual parsing, no Flutter).
// Reads schema from appwrite/tables_schema.json.
// Skips any resource that already exists (HTTP 409).
// Does NOT create Users, API Keys, or modify Auth settings.
// Does NOT print secret keys.
// ===========================================================

import 'dart:convert';
import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/enums.dart' as enums;

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

// --------------- mask helper ---------------
String _mask(String value) {
  if (value.length <= 8) return '****';
  return '${value.substring(0, 4)}${'*' * (value.length - 8)}${value.substring(value.length - 4)}';
}

// --------------- index type helper ---------------
enums.TablesDBIndexType _indexType(String type) {
  switch (type) {
    case 'unique':
      return enums.TablesDBIndexType.unique;
    case 'fulltext':
      return enums.TablesDBIndexType.fulltext;
    case 'key':
    default:
      return enums.TablesDBIndexType.key;
  }
}

// --------------- main ---------------
Future<void> main() async {
  print('========================================');
  print('  HR Database Setup Script (TablesDB)');
  print('========================================\n');

  // 1. Read .env
  final env = _parseEnvFile('.env');
  final endpoint = env['APPWRITE_ENDPOINT'] ?? '';
  final projectId = env['APPWRITE_PROJECT_ID'] ?? '';
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';
  final apiKey = env['APPWRITE_API_KEY'] ?? '';

  if (endpoint.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
    print('ERROR: Missing required environment variables in .env');
    print('Required: APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY');
    if (apiKey.isEmpty) {
      print(
        '\nHint: Create an API Key in Appwrite Console with Databases (read+write)',
      );
      print('permissions, then add to .env as:');
      print('APPWRITE_API_KEY=your_key_here');
    }
    exit(1);
  }

  print('Endpoint:   $endpoint');
  print('Project:    $projectId');
  print('Database:   $databaseId');
  print('');
  print('');

  // 2. Read schema
  final schemaFile = File('appwrite/tables_schema.json');
  if (!schemaFile.existsSync()) {
    print('ERROR: Schema file not found at appwrite/tables_schema.json');
    exit(1);
  }
  final schema =
      jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
  print('Schema loaded from appwrite/tables_schema.json\n');

  // 3. Init Appwrite client
  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final tablesDB = TablesDB(client);

  // ===================== CHECK DATABASE =====================
  print('--- Step 1: Check Database ---');
  try {
    await tablesDB.get(databaseId: databaseId);
    print('[OK] Database exists: $databaseId');
  } on AppwriteException catch (e) {
    print('Database not found: $databaseId');
    print('Error: ${e.message}');
    exit(1);
  }

  // ===================== CREATE TABLES + COLUMNS =====================
  final tables = schema['tables'] as List;
  print('\n--- Step 2: Create Tables & Columns ---');

  for (final table in tables) {
    final tableId = table['id'] as String;
    final tableName = table['name'] as String;

    // Create table
    try {
      await tablesDB.createTable(
        databaseId: databaseId,
        tableId: tableId,
        name: tableName,
      );
      print('\n[CREATED] Table: $tableId');
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        print('\n[EXISTS]  Table: $tableId');
      } else {
        print('\n[FAILED]  Table $tableId: ${e.message}');
        continue;
      }
    }

    // Create columns
    final columns = table['columns'] as List;
    for (final col in columns) {
      final key = col[0] as String;
      final type = col[1] as String;
      final size = col[2];
      final required = col[3] as bool;

      try {
        switch (type) {
          case 'string':
            if (size != null && (size as int) >= 512) {
              // Text for long fields (512+ characters)
              await tablesDB.createTextColumn(
                databaseId: databaseId,
                tableId: tableId,
                key: key,
                xrequired: required,
              );
            } else {
              // Varchar for short fields
              await tablesDB.createVarcharColumn(
                databaseId: databaseId,
                tableId: tableId,
                key: key,
                size: (size as int?) ?? 255,
                xrequired: required,
              );
            }
          case 'float':
            await tablesDB.createFloatColumn(
              databaseId: databaseId,
              tableId: tableId,
              key: key,
              xrequired: required,
            );
          case 'integer':
            await tablesDB.createIntegerColumn(
              databaseId: databaseId,
              tableId: tableId,
              key: key,
              xrequired: required,
            );
          case 'boolean':
            await tablesDB.createBooleanColumn(
              databaseId: databaseId,
              tableId: tableId,
              key: key,
              xrequired: required,
            );
          case 'datetime':
            await tablesDB.createDatetimeColumn(
              databaseId: databaseId,
              tableId: tableId,
              key: key,
              xrequired: required,
            );
          default:
            print('  [WARN]  Unknown column type: $type for $key');
        }
        print(
          '  [CREATED] Column: $key ($type${size != null ? ", size=$size" : ""})',
        );
      } on AppwriteException catch (e) {
        if (e.code == 409) {
          print('  [EXISTS]  Column: $key');
        } else {
          print('  [FAILED]  Column $key: ${e.message}');
        }
      }
    }
  }

  // Wait for column processing before creating indexes
  print('\nWaiting 8 seconds for columns to be processed...');
  await Future.delayed(const Duration(seconds: 8));

  // ===================== CREATE INDEXES =====================
  print('\n--- Step 3: Create Indexes ---');
  for (final table in tables) {
    final tableId = table['id'] as String;
    final indexes = table['indexes'] as List?;
    if (indexes == null || indexes.isEmpty) continue;

    for (final idx in indexes) {
      final idxKey = idx[0] as String;
      final idxType = idx[1] as String;
      final attributes = List<String>.from(idx[2] as List);

      try {
        await tablesDB.createIndex(
          databaseId: databaseId,
          tableId: tableId,
          key: idxKey,
          type: _indexType(idxType),
          columns: attributes,
        );
        print(
          '[CREATED] Index: $idxKey on $tableId (${attributes.join(", ")})',
        );
      } on AppwriteException catch (e) {
        if (e.code == 409) {
          print('[EXISTS]  Index: $idxKey on $tableId');
        } else {
          print('[FAILED]  Index $idxKey on $tableId: ${e.message}');
        }
      }
    }
  }

  // ===================== VERIFICATION =====================
  print('\n--- Step 4: Verification ---');
  try {
    final dbInfo = await tablesDB.get(databaseId: databaseId);
    print('[OK] Database "${dbInfo.name}" (${dbInfo.$id})');
  } catch (e) {
    print('[FAIL] Could not verify database: $e');
  }

  final expectedTables = [
    'profiles',
    'attendance_records',
    'penalties',
    'payroll_records',
    'advances',
    'announcements',
    'shifts',
    'employee_shift_assignments',
    'employee_work_schedules',
  ];
  for (final tid in expectedTables) {
    try {
      final tbl = await tablesDB.getTable(databaseId: databaseId, tableId: tid);
      print('[OK] Table: ${tbl.name} (${tbl.$id})');
    } catch (e) {
      print('[MISSING] Table: $tid');
    }
  }

  // Verify profiles columns
  print('\nVerifying profiles columns...');
  final profileCols = [
    'company_id',
    'employee_number',
    'full_name',
    'role',
    'phone',
    'photo_path',
    'department_id',
    'department_name',
    'job_title_id',
    'job_title_name',
    'hire_date',
    'base_salary',
    'monthly_bonus',
    'daily_work_hours',
    'active',
    'must_change_password',
  ];
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'profiles',
    );
    final existingKeys = <String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        existingKeys.add((a.data as Map)['key']?.toString() ?? '');
      }
    }
    for (final col in profileCols) {
      print(existingKeys.contains(col) ? '  [OK] $col' : '  [MISSING] $col');
    }
  } catch (e) {
    print('  Could not verify profiles columns: $e');
  }

  // Verify payroll_records columns
  print('\nVerifying payroll_records columns...');
  final payrollCols = [
    'base_salary',
    'monthly_bonus',
    'monthly_entitlement',
    'net_salary',
  ];
  try {
    final cols = await tablesDB.listColumns(
      databaseId: databaseId,
      tableId: 'payroll_records',
    );
    final existingKeys = <String>{};
    for (final a in cols.columns) {
      if (a.data is Map) {
        existingKeys.add((a.data as Map)['key']?.toString() ?? '');
      }
    }
    for (final col in payrollCols) {
      print(existingKeys.contains(col) ? '  [OK] $col' : '  [MISSING] $col');
    }
  } catch (e) {
    print('  Could not verify payroll_records columns: $e');
  }

  print('\n========================================');
  print('  Setup Complete!');
  print('========================================');
}
