import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as models;
import 'package:hr_employee_system/services/excel_attendance_import_parser.dart';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0]] = parts.sublist(1).join('=').trim().replaceAll("'", "");
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final apiKey = env['APPWRITE_API_KEY'];
  final databaseId = env['APPWRITE_DATABASE_ID'];

  if (projectId == null || apiKey == null || databaseId == null) {
    print('Missing Appwrite variables in .env');
    exit(1);
  }

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);

  final databases = Databases(client);

  try {
    print('==================================================');
    print('Fetching Schema and Permissions');
    print('==================================================');
    final collection = await databases.getCollection(
      databaseId: databaseId,
      collectionId: 'temporary_biometric_employees',
    );

    print('Permissions:');
    for (var perm in collection.$permissions) {
      print('- $perm');
    }

    print('\nAttributes:');
    for (var attr in collection.attributes) {
      final map = attr as Map<String, dynamic>;
      final key = map['key'];
      final type = map['type'];
      final required = map['required'];
      final def = map['default'];
      print('- key: $key, type: $type, required: $required, default: $def');
    }

    print('\n==================================================');
    print('Fetching Data Counts');
    print('==================================================');

    // Fetch ALL rows with pagination (Appwrite default limit = 25)
    final allDocs = <models.Document>[];
    String? lastId;
    while (true) {
      final queries = <String>[Query.limit(100)];
      if (lastId != null) {
        queries.add(Query.cursorAfter(lastId));
      }
      final res = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'temporary_biometric_employees',
        queries: queries,
      );
      allDocs.addAll(res.documents);
      if (res.documents.length < 100) break;
      lastId = res.documents.last.$id;
    }

    print('Total rows: ${allDocs.length}');

    // Count by status
    final statusCounts = <String, int>{};
    int emptyOrNull = 0;
    int withImportedName = 0;
    int withoutImportedName = 0;
    for (var doc in allDocs) {
      final status = doc.data['status'];
      final importedName = doc.data['employee_name_from_device']
          ?.toString()
          .trim();
      if (importedName != null && importedName.isNotEmpty) {
        withImportedName++;
      } else {
        withoutImportedName++;
      }
      if (status == null || (status is String && status.trim().isEmpty)) {
        emptyOrNull++;
      } else {
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }

    // Print known statuses first
    for (final s in ['pending', 'approved', 'rejected', 'linked']) {
      print('$s: ${statusCounts[s] ?? 0}');
    }
    // Print any other unexpected statuses
    int otherCount = 0;
    for (final entry in statusCounts.entries) {
      if (!['pending', 'approved', 'rejected', 'linked'].contains(entry.key)) {
        print('other (${entry.key}): ${entry.value}');
        otherCount += entry.value;
      }
    }
    if (otherCount == 0) print('other: 0');
    print('empty_or_null: $emptyOrNull');
    print('with_employee_name_from_device: $withImportedName');
    print('without_employee_name_from_device: $withoutImportedName');

    // Verify sum
    final sum = statusCounts.values.fold(0, (a, b) => a + b) + emptyOrNull;
    print(
      'Sum check: $sum == ${allDocs.length} => ${sum == allDocs.length ? "OK" : "MISMATCH"}',
    );

    // Duplicate check
    final bioIdGroups = <String, List<String>>{};
    for (var doc in allDocs) {
      final bioId = doc.data['biometric_employee_id'] as String;
      bioIdGroups.putIfAbsent(bioId, () => []);
      bioIdGroups[bioId]!.add(doc.$id);
    }
    final duplicates = bioIdGroups.entries
        .where((e) => e.value.length > 1)
        .toList();
    print('\nDuplicate biometric_employee_id count: ${duplicates.length}');
    if (duplicates.isNotEmpty) {
      final show = duplicates.take(10);
      for (var dup in show) {
        print('  ${dup.key}: ${dup.value.length} rows => ${dup.value}');
      }
      if (duplicates.length > 10) {
        print('  ... and ${duplicates.length - 10} more');
      }
    }

    print('\nFirst 50 rows:');
    for (var i = 0; i < allDocs.length && i < 50; i++) {
      final doc = allDocs[i];
      print('- \$id: ${doc.$id}');
      print('  company_id: ${doc.data['company_id']}');
      print('  biometric_employee_id: ${doc.data['biometric_employee_id']}');
      print(
        '  employee_name_from_device: ${doc.data['employee_name_from_device']}',
      );
      print('  status: ${doc.data['status']}');
      print('  punches_count: ${doc.data['punches_count']}');
      print('  first_seen_at: ${doc.data['first_seen_at']}');
      print('  last_seen_at: ${doc.data['last_seen_at']}');
      print('  source_batch_id: ${doc.data['source_batch_id']}');
      print('  notes: ${doc.data['notes']}');
      print('---');
    }

    print('\n==================================================');
    print('Excel unmatched biometric id row check');
    print('==================================================');

    final excelFile = File('test_data/emps.xlsx');
    if (!excelFile.existsSync()) {
      print('test_data/emps.xlsx not found');
      return;
    }

    final parsed = ExcelAttendanceImportParser.parse(
      excelFile.readAsBytesSync(),
    );
    final excelBioIds = parsed.summary.groups.map((g) => g.biometricId).toSet();
    final profiles = <models.Document>[];
    String? profileLastId;
    while (true) {
      final queries = <String>[Query.limit(100)];
      if (profileLastId != null) {
        queries.add(Query.cursorAfter(profileLastId));
      }
      final res = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'profiles',
        queries: queries,
      );
      profiles.addAll(res.documents);
      if (res.documents.length < 100) break;
      profileLastId = res.documents.last.$id;
    }

    final profileBioIds = profiles
        .map((doc) => doc.data['biometric_employee_id']?.toString())
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final docsById = {for (final doc in allDocs) doc.$id: doc};
    final unmatched =
        excelBioIds.where((id) => !profileBioIds.contains(id)).toList()..sort();

    print('unmatchedBiometricIdsFromExcel: ${unmatched.join(', ')}');
    print('unmatched count: ${unmatched.length}');
    for (final id in unmatched) {
      final expectedRowId = _safeRowId('temp_$id');
      final doc = docsById[expectedRowId];
      print(
        '$id | $expectedRowId | ${doc == null ? 'no' : 'yes'} | ${doc?.data['status'] ?? '-'} | ${doc?.data['company_id'] ?? '-'} | ${doc?.data['employee_name_from_device'] ?? '-'}',
      );
    }
  } catch (e) {
    print('Error: $e');
  }
}

String _safeRowId(String input) {
  final cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  if (cleaned.length <= 32) return cleaned;
  return '${cleaned.substring(0, 20)}_${cleaned.hashCode.abs()}';
}
