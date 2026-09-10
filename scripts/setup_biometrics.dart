// ignore_for_file: avoid_print
import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/enums.dart' as enums;

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
  print('  Setup Biometrics Tables Script');
  print('========================================\n');

  final env = _parseEnvFile('.env');
  final endpoint = env['APPWRITE_ENDPOINT'] ?? '';
  final projectId = env['APPWRITE_PROJECT_ID'] ?? '';
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';
  final apiKey = env['APPWRITE_API_KEY'] ?? '';

  if (endpoint.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
    print('ERROR: Missing required environment variables in .env');
    exit(1);
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final tablesDB = TablesDB(client);

  print('--- Checking profiles table ---');
  try {
    await tablesDB.createStringColumn(
      databaseId: databaseId,
      tableId: 'profiles',
      key: 'biometric_employee_id',
      size: 40,
      xrequired: false,
    );
    print('[CREATED] Column: biometric_employee_id in profiles');
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      print('[EXISTS]  Column: biometric_employee_id in profiles');
    } else {
      print('[FAILED]  Column biometric_employee_id: ${e.message}');
    }
  }

  print('\n--- Creating biometric_import_batches ---');
  final batchTable = 'biometric_import_batches';
  try {
    await tablesDB.createTable(
      databaseId: databaseId,
      tableId: batchTable,
      name: 'Biometric Import Batches',
    );
    print('[CREATED] Table: $batchTable');
  } catch (e) {
    print('[EXISTS] Table: $batchTable');
  }

  print('\n--- Creating biometric_logs ---');
  final logsTable = 'biometric_logs';
  try {
    await tablesDB.createTable(
      databaseId: databaseId,
      tableId: logsTable,
      name: 'Biometric Logs',
    );
    print('[CREATED] Table: $logsTable');
  } catch (e) {
    print('[EXISTS] Table: $logsTable');
  }

  print('\n--- Creating shifts ---');
  final shiftsTable = 'shifts';
  try {
    await tablesDB.createTable(
      databaseId: databaseId,
      tableId: shiftsTable,
      name: 'Shifts',
    );
    print('[CREATED] Table: $shiftsTable');
  } catch (e) {
    print('[EXISTS] Table: $shiftsTable');
  }

  print('\n--- Creating employee_shift_assignments ---');
  final assignmentsTable = 'employee_shift_assignments';
  try {
    await tablesDB.createTable(
      databaseId: databaseId,
      tableId: assignmentsTable,
      name: 'Employee Shift Assignments',
    );
    print('[CREATED] Table: $assignmentsTable');
  } catch (e) {
    print('[EXISTS] Table: $assignmentsTable');
  }

  print('\n--- Creating overtime_records ---');
  final overtimeTable = 'overtime_records';
  try {
    await tablesDB.createTable(
      databaseId: databaseId,
      tableId: overtimeTable,
      name: 'Overtime Records',
    );
    print('[CREATED] Table: $overtimeTable');
  } catch (e) {
    print('[EXISTS] Table: $overtimeTable');
  }

  print('\nWaiting 3 seconds before adding columns...');
  await Future.delayed(const Duration(seconds: 3));

  Future<void> createCol(
    String table,
    String key,
    String type, {
    bool req = false,
    int? size,
  }) async {
    try {
      if (type == 'string') {
        if (size != null && size >= 500) {
          await tablesDB.createTextColumn(
            databaseId: databaseId,
            tableId: table,
            key: key,
            xrequired: req,
          );
        } else {
          await tablesDB.createStringColumn(
            databaseId: databaseId,
            tableId: table,
            key: key,
            size: size ?? 255,
            xrequired: req,
          );
        }
      } else if (type == 'integer') {
        await tablesDB.createIntegerColumn(
          databaseId: databaseId,
          tableId: table,
          key: key,
          xrequired: req,
        );
      } else if (type == 'float') {
        await tablesDB.createFloatColumn(
          databaseId: databaseId,
          tableId: table,
          key: key,
          xrequired: req,
        );
      } else if (type == 'boolean') {
        await tablesDB.createBooleanColumn(
          databaseId: databaseId,
          tableId: table,
          key: key,
          xrequired: req,
        );
      } else if (type == 'datetime') {
        await tablesDB.createDatetimeColumn(
          databaseId: databaseId,
          tableId: table,
          key: key,
          xrequired: req,
        );
      }
      print('  [CREATED] $table.$key');
    } catch (e) {
      print('  [EXISTS/ERROR] $table.$key: $e');
    }
  }

  // Batch
  await createCol(batchTable, 'company_id', 'string', req: true, size: 36);
  await createCol(batchTable, 'file_name', 'string', req: true, size: 255);
  await createCol(batchTable, 'imported_by', 'string', req: true, size: 80);
  await createCol(batchTable, 'imported_at', 'datetime', req: true);
  await createCol(batchTable, 'status', 'string', req: true, size: 32);
  await createCol(batchTable, 'total_rows', 'integer', req: true);
  await createCol(batchTable, 'valid_rows', 'integer', req: true);
  await createCol(batchTable, 'invalid_rows', 'integer', req: true);
  await createCol(batchTable, 'processed_rows', 'integer', req: true);
  await createCol(batchTable, 'notes', 'string', req: false, size: 4000);

  // Logs
  await createCol(logsTable, 'company_id', 'string', req: true, size: 36);
  await createCol(logsTable, 'import_batch_id', 'string', req: true, size: 80);
  await createCol(
    logsTable,
    'biometric_employee_id',
    'string',
    req: true,
    size: 40,
  );
  await createCol(logsTable, 'employee_id', 'string', req: false, size: 80);
  await createCol(
    logsTable,
    'employee_name_from_device',
    'string',
    req: false,
    size: 180,
  );
  await createCol(logsTable, 'punch_time', 'datetime', req: true);
  await createCol(logsTable, 'punch_type', 'string', req: false, size: 20);
  await createCol(logsTable, 'raw_line', 'string', req: false, size: 4000);
  await createCol(logsTable, 'is_matched', 'boolean', req: true);
  await createCol(logsTable, 'is_processed', 'boolean', req: true);
  await createCol(logsTable, 'error_message', 'string', req: false, size: 4000);
  await createCol(logsTable, 'created_at', 'datetime', req: true);

  // Shifts
  await createCol(shiftsTable, 'company_id', 'string', req: true, size: 36);
  await createCol(shiftsTable, 'name', 'string', req: true, size: 120);
  await createCol(shiftsTable, 'start_time', 'string', req: true, size: 10);
  await createCol(shiftsTable, 'end_time', 'string', req: true, size: 10);
  await createCol(shiftsTable, 'grace_late_minutes', 'integer', req: false);
  await createCol(
    shiftsTable,
    'grace_early_leave_minutes',
    'integer',
    req: false,
  );
  await createCol(shiftsTable, 'is_overnight', 'boolean', req: true);
  await createCol(shiftsTable, 'active', 'boolean', req: true);

  // Assignments
  await createCol(
    assignmentsTable,
    'company_id',
    'string',
    req: true,
    size: 36,
  );
  await createCol(
    assignmentsTable,
    'employee_id',
    'string',
    req: true,
    size: 80,
  );
  await createCol(assignmentsTable, 'work_date', 'datetime', req: true);
  await createCol(assignmentsTable, 'shift_id', 'string', req: true, size: 80);
  await createCol(assignmentsTable, 'created_at', 'datetime', req: true);

  // Overtime
  await createCol(overtimeTable, 'company_id', 'string', req: true, size: 36);
  await createCol(overtimeTable, 'employee_id', 'string', req: true, size: 80);
  await createCol(
    overtimeTable,
    'attendance_record_id',
    'string',
    req: false,
    size: 80,
  );
  await createCol(overtimeTable, 'work_date', 'datetime', req: true);
  await createCol(overtimeTable, 'shift_end', 'datetime', req: true);
  await createCol(overtimeTable, 'actual_check_out', 'datetime', req: true);
  await createCol(overtimeTable, 'overtime_minutes', 'integer', req: true);
  await createCol(overtimeTable, 'overtime_amount', 'float', req: false);
  await createCol(
    overtimeTable,
    'approval_status',
    'string',
    req: true,
    size: 32,
  );
  await createCol(
    overtimeTable,
    'payment_status',
    'string',
    req: true,
    size: 32,
  );
  await createCol(overtimeTable, 'approved_by', 'string', req: false, size: 80);
  await createCol(overtimeTable, 'approved_at', 'datetime', req: false);
  await createCol(overtimeTable, 'paid_by', 'string', req: false, size: 80);
  await createCol(overtimeTable, 'paid_at', 'datetime', req: false);
  await createCol(overtimeTable, 'paid_amount', 'float', req: false);
  await createCol(overtimeTable, 'created_at', 'datetime', req: true);

  print('\nWaiting 5 seconds before adding indexes...');
  await Future.delayed(const Duration(seconds: 5));

  try {
    await tablesDB.createIndex(
      databaseId: databaseId,
      tableId: logsTable,
      key: 'biometric_employee_time_idx',
      type: enums.TablesDBIndexType.key,
      columns: ['biometric_employee_id', 'punch_time'],
    );
    print('  [CREATED] Index: biometric_employee_time_idx');
  } catch (e) {
    print('  [EXISTS/ERROR] Index: biometric_employee_time_idx: $e');
  }

  try {
    await tablesDB.createIndex(
      databaseId: databaseId,
      tableId: logsTable,
      key: 'biometric_batch_idx',
      type: enums.TablesDBIndexType.key,
      columns: ['import_batch_id'],
    );
    print('  [CREATED] Index: biometric_batch_idx');
  } catch (e) {
    print('  [EXISTS/ERROR] Index: biometric_batch_idx: $e');
  }

  try {
    await tablesDB.createIndex(
      databaseId: databaseId,
      tableId: assignmentsTable,
      key: 'employee_shift_date_idx',
      type: enums.TablesDBIndexType.key,
      columns: ['employee_id', 'work_date'],
    );
    print('  [CREATED] Index: employee_shift_date_idx');
  } catch (e) {
    print('  [EXISTS/ERROR] Index: employee_shift_date_idx: $e');
  }

  print('\n--- Seeding Default Shifts ---');
  try {
    final docs = await tablesDB.listRows(
      databaseId: databaseId,
      tableId: shiftsTable,
      queries: [Query.equal('company_id', 'company_main')],
    );

    if (docs.total == 0) {
      final defaultShifts = [
        {
          'company_id': 'company_main',
          'name': 'صباحي',
          'start_time': '06:00',
          'end_time': '14:00',
          'is_overnight': false,
          'active': true,
        },
        {
          'company_id': 'company_main',
          'name': 'مسائي',
          'start_time': '14:00',
          'end_time': '22:00',
          'is_overnight': false,
          'active': true,
        },
        {
          'company_id': 'company_main',
          'name': 'ليلي',
          'start_time': '22:00',
          'end_time': '06:00',
          'is_overnight': true,
          'active': true,
        },
      ];

      for (var shift in defaultShifts) {
        await tablesDB.createRow(
          databaseId: databaseId,
          tableId: shiftsTable,
          rowId: ID.unique(),
          data: shift,
        );
      }
      print('  [OK] Default shifts seeded.');
    } else {
      print('  [SKIP] Shifts already exist.');
    }
  } catch (e) {
    print('  [ERROR] Failed to seed shifts: $e');
  }

  print('========================================');
  print('  Setup Biometrics Completed!');
  print('========================================');
}
