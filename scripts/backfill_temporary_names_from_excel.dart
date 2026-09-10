import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as models;
import 'package:hr_employee_system/services/excel_attendance_import_parser.dart';

void main() async {
  final env = await _readEnv();
  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final apiKey = env['APPWRITE_API_KEY'];
  final databaseId = env['APPWRITE_DATABASE_ID'];

  if (projectId == null || apiKey == null || databaseId == null) {
    print('Missing Appwrite variables in .env');
    exit(1);
  }

  final excelFile = File('test_data/emps.xlsx');
  if (!excelFile.existsSync()) {
    print('test_data/emps.xlsx not found');
    exit(1);
  }

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
  final databases = Databases(client);

  final parsed = ExcelAttendanceImportParser.parse(excelFile.readAsBytesSync());
  final namesByBiometricId = <String, String>{};
  for (final group in parsed.summary.groups) {
    final name = group.employeeName?.trim();
    if (name != null && name.isNotEmpty) {
      namesByBiometricId.putIfAbsent(group.biometricId, () => name);
    }
  }

  final profiles = await _listAll(databases, databaseId, 'profiles');
  final profileBioIds = profiles
      .map((doc) => doc.data['biometric_employee_id']?.toString().trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();

  var checkedUnmatched = 0;
  var existingWithEmptyName = 0;
  var updated = 0;
  var skippedAlreadyNamed = 0;
  var missingTemporary = 0;
  var failed = 0;

  final unmatchedIds =
      namesByBiometricId.keys
          .where((id) => !profileBioIds.contains(id))
          .toList()
        ..sort();

  for (final bioId in unmatchedIds) {
    checkedUnmatched++;
    final tempId = _safeRowId('temp_$bioId');
    models.Document temp;
    try {
      temp = await databases.getDocument(
        databaseId: databaseId,
        collectionId: 'temporary_biometric_employees',
        documentId: tempId,
      );
    } catch (_) {
      missingTemporary++;
      continue;
    }

    final currentName = temp.data['employee_name_from_device']
        ?.toString()
        .trim();
    if (currentName != null && currentName.isNotEmpty) {
      skippedAlreadyNamed++;
      continue;
    }

    existingWithEmptyName++;
    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: 'temporary_biometric_employees',
        documentId: tempId,
        data: {'employee_name_from_device': namesByBiometricId[bioId]},
      );
      updated++;
    } catch (e) {
      failed++;
      print('update_failed: $bioId | $tempId | $e');
    }
  }

  print('checked_unmatched: $checkedUnmatched');
  print('existing_with_empty_name: $existingWithEmptyName');
  print('updated_employee_name_from_device: $updated');
  print('skipped_already_named: $skippedAlreadyNamed');
  print('missing_temporary: $missingTemporary');
  print('failed: $failed');
}

Future<Map<String, String>> _readEnv() async {
  final lines = await File('.env').readAsLines();
  final env = <String, String>{};
  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length < 2) continue;
    env[parts.first.trim()] = parts
        .sublist(1)
        .join('=')
        .trim()
        .replaceAll("'", "");
  }
  return env;
}

Future<List<models.Document>> _listAll(
  Databases databases,
  String databaseId,
  String collectionId,
) async {
  final docs = <models.Document>[];
  String? lastId;
  while (true) {
    final queries = <String>[Query.limit(100)];
    if (lastId != null) queries.add(Query.cursorAfter(lastId));
    final res = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: queries,
    );
    docs.addAll(res.documents);
    if (res.documents.length < 100) break;
    lastId = res.documents.last.$id;
  }
  return docs;
}

String _safeRowId(String input) {
  final cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  if (cleaned.length <= 32) return cleaned;
  return '${cleaned.substring(0, 20)}_${cleaned.hashCode.abs()}';
}
