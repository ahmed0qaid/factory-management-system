import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' as models;

const dryRun = false;

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts
          .sublist(1)
          .join('=')
          .trim()
          .replaceAll("'", "");
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
  final collectionId = 'temporary_biometric_employees';

  try {
    print('==================================================');
    print('Audit Duplicate Temporary Employees');
    print('dryRun = $dryRun');
    print('==================================================');

    // 1. Fetch ALL rows with pagination
    final allDocs = <models.Document>[];
    String? lastId;
    while (true) {
      final queries = <String>[Query.limit(100)];
      if (lastId != null) {
        queries.add(Query.cursorAfter(lastId));
      }
      final res = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: queries,
      );
      allDocs.addAll(res.documents);
      if (res.documents.length < 100) break;
      lastId = res.documents.last.$id;
    }

    print('Total rows fetched: ${allDocs.length}');

    // 2. Group by biometric_employee_id
    final groups = <String, List<models.Document>>{};
    for (var doc in allDocs) {
      final bioId = doc.data['biometric_employee_id'] as String;
      groups.putIfAbsent(bioId, () => []);
      groups[bioId]!.add(doc);
    }

    // 3. Find duplicates
    final duplicateGroups = <String, List<models.Document>>{};
    for (var entry in groups.entries) {
      if (entry.value.length > 1) {
        duplicateGroups[entry.key] = entry.value;
      }
    }

    print('Unique biometric_employee_id count: ${groups.length}');
    print('Duplicate biometric_employee_id count: ${duplicateGroups.length}');

    if (duplicateGroups.isEmpty) {
      print('\nNo duplicates found. Nothing to do.');
      return;
    }

    // 4. For each duplicate group, decide KEEP vs REMOVE
    final toRemove = <String>[]; // rowIds to delete

    print('\n==================================================');
    print('Duplicate Details');
    print('==================================================');

    for (var entry in duplicateGroups.entries) {
      final bioId = entry.key;
      final docs = entry.value;

      print('\nbiometric_employee_id: $bioId');
      print('  duplicate count: ${docs.length}');

      for (var doc in docs) {
        print('  - rowId: ${doc.$id}');
        print('    status: ${doc.data['status']}');
        print('    punches_count: ${doc.data['punches_count']}');
        print('    first_seen_at: ${doc.data['first_seen_at']}');
        print('    last_seen_at: ${doc.data['last_seen_at']}');
        print('    notes: ${doc.data['notes']}');
      }

      // Choose KEEP:
      // a. rowId == temp_${biometric_employee_id}
      final expectedId = 'temp_$bioId';
      models.Document? keeper;

      for (var doc in docs) {
        if (doc.$id == expectedId) {
          keeper = doc;
          break;
        }
      }

      // b. If no match, pick most recent last_seen_at
      if (keeper == null) {
        docs.sort((a, b) {
          final aTime = a.data['last_seen_at'] ?? '';
          final bTime = b.data['last_seen_at'] ?? '';
          return bTime.toString().compareTo(aTime.toString());
        });
        keeper = docs.first;
      }

      // c. If still tied (shouldn't happen), pick highest punches_count
      // Already handled by sort above as fallback

      print('  KEEP: ${keeper.$id}');
      final duplicates = docs
          .where((d) => d.$id != keeper!.$id)
          .map((d) => d.$id)
          .toList();
      print('  DUPLICATES_TO_REMOVE: $duplicates');
      toRemove.addAll(duplicates);
    }

    print('\n==================================================');
    print('Summary');
    print('==================================================');
    print('Total duplicates to remove: ${toRemove.length}');
    print('Rows to remove:');
    for (var id in toRemove) {
      print('  - $id');
    }

    // 5. Execute deletion if not dryRun
    if (!dryRun) {
      print('\n==================================================');
      print('Executing Deletion');
      print('==================================================');
      int deleted = 0;
      for (var id in toRemove) {
        try {
          print('Deleting duplicate row: $id');
          await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: id,
          );
          deleted++;
        } catch (e) {
          print('  FAILED to delete $id: $e');
        }
      }
      print('Deleted count = $deleted');
    } else {
      print('\ndryRun = true. No rows deleted.');
      print('Set dryRun = false and re-run to execute deletion.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
