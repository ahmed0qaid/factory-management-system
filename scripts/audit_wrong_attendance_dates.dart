import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' hide File;

// ---------------------------------------------------------
// Configuration
// ---------------------------------------------------------
const bool dryRun = false;

String _safeRowId(String input) {
  final cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  if (cleaned.length <= 32) return cleaned;
  return '${cleaned.substring(0, 20)}_${cleaned.hashCode.abs()}';
}

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found.');
    return;
  }
  
  final envLines = envFile.readAsLinesSync();
  final env = <String, String>{};
  for (var line in envLines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT']!;
  final projectId = env['APPWRITE_PROJECT_ID']!;
  final apiKey = env['APPWRITE_API_KEY']!;
  final dbId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  final client = Client()
    .setEndpoint(endpoint)
    .setProject(projectId)
    .setKey(apiKey);
    
  final databases = Databases(client);
  
  print('==================================================');
  print('تشخيص تواريخ الدوام الخاطئة (dryRun=$dryRun)');
  print('==================================================');

  try {
    final response = await databases.listDocuments(
      databaseId: dbId,
      collectionId: 'attendance_records',
      queries: [
        Query.limit(500),
      ],
    );

    final records = response.documents;
    final suspiciousDocs = <Document>[];

    for (final doc in records) {
      final workDateStr = doc.data['work_date'] as String?;
      if (workDateStr == null) continue;

      // Looking for swapped Jan 8 and Feb 8
      if (workDateStr.startsWith('2026-01-08') || workDateStr.startsWith('2026-02-08')) {
        suspiciousDocs.add(doc);
      }
    }

    print('-> عدد السجلات الإجمالي الممشوطة: ${records.length}');
    print('-> عدد السجلات المشتبه بها (تاريخ معكوس): ${suspiciousDocs.length}');
    print('');

    if (suspiciousDocs.isEmpty) {
      print('لا توجد سجلات تحتاج إلى تصحيح.');
      return;
    }

    int i = 0;
    int willCorrectCount = 0;

    for (final doc in suspiciousDocs) {
      final oldRowId = doc.$id;
      final record = doc.data;
      final empId = record['employee_id'] as String;
      final status = record['status'] as String;
      final oldWorkDateStr = record['work_date'] as String;
      final oldCheckInStr = record['check_in'] as String?;
      final oldCheckOutStr = record['check_out'] as String?;
      final oldStartStr = record['scheduled_start'] as String?;
      final oldEndStr = record['scheduled_end'] as String?;

      DateTime oldWorkDate = DateTime.parse(oldWorkDateStr);
      
      // Swap month and day
      final newWorkDate = DateTime(oldWorkDate.year, oldWorkDate.day, oldWorkDate.month);
      final newWorkDateStr = newWorkDate.toIso8601String();

      String? fixDateTime(String? oldDtStr) {
        if (oldDtStr == null || oldDtStr.isEmpty) return null;
        DateTime oldDt = DateTime.parse(oldDtStr);
        if (oldDt.year == oldWorkDate.year && oldDt.month == oldWorkDate.month && oldDt.day == oldWorkDate.day) {
          return DateTime(oldDt.year, oldDt.day, oldDt.month, oldDt.hour, oldDt.minute, oldDt.second).toIso8601String();
        }
        DateTime nextDayOld = oldWorkDate.add(Duration(days: 1));
        if (oldDt.year == nextDayOld.year && oldDt.month == nextDayOld.month && oldDt.day == nextDayOld.day) {
          DateTime nextDayNew = newWorkDate.add(Duration(days: 1));
          return DateTime(nextDayNew.year, nextDayNew.month, nextDayNew.day, oldDt.hour, oldDt.minute, oldDt.second).toIso8601String();
        }
        return oldDtStr; 
      }

      final newCheckInStr = fixDateTime(oldCheckInStr);
      final newCheckOutStr = fixDateTime(oldCheckOutStr);
      final newStartStr = fixDateTime(oldStartStr);
      final newEndStr = fixDateTime(oldEndStr);

      final dateStr = newWorkDateStr.substring(0, 10);
      final sStart = newStartStr ?? 'none';
      final sEnd = newEndStr ?? 'none';
      final newRowId = _safeRowId('att_${empId}_${dateStr}_${sStart}_$sEnd');

      bool newExists = false;
      try {
        await databases.getDocument(
          databaseId: dbId,
          collectionId: 'attendance_records',
          documentId: newRowId,
        );
        newExists = true;
      } catch (e) {
        newExists = false;
      }

      if (i < 10) {
        print('----------------------------------------');
        print('مثال رقم ${i + 1}:');
        print('  - rowId: $oldRowId');
        print('  - employee_id: $empId');
        print('  - status: $status');
        print('  - [القديم] work_date: $oldWorkDateStr');
        if (oldCheckInStr != null) print('  - [القديم] check_in: $oldCheckInStr');
        if (oldCheckOutStr != null) print('  - [القديم] check_out: $oldCheckOutStr');
        print('  - [الجديد] work_date: $newWorkDateStr');
        if (newCheckInStr != null) print('  - [الجديد] check_in: $newCheckInStr');
        if (newCheckOutStr != null) print('  - [الجديد] check_out: $newCheckOutStr');
        print('  - newRowId: $newRowId');
        print('  - newRowExists: ${newExists ? 'yes (خطر تكرار!)' : 'no (آمن للتصحيح)'}');
      }
      i++;
      
      if (!newExists) {
        willCorrectCount++;
        if (!dryRun) {
          final newRecordData = Map<String, dynamic>.from(record);
          newRecordData.removeWhere((key, value) => key.startsWith(r'$'));
          newRecordData['work_date'] = newWorkDateStr;
          if (newCheckInStr != null) newRecordData['check_in'] = newCheckInStr;
          if (newCheckOutStr != null) newRecordData['check_out'] = newCheckOutStr;
          if (newStartStr != null) newRecordData['scheduled_start'] = newStartStr;
          if (newEndStr != null) newRecordData['scheduled_end'] = newEndStr;

          try {
            await databases.createDocument(
              databaseId: dbId,
              collectionId: 'attendance_records',
              documentId: newRowId,
              data: newRecordData,
              permissions: doc.$permissions,
            );
            
            await databases.deleteDocument(
              databaseId: dbId,
              collectionId: 'attendance_records',
              documentId: oldRowId,
            );
            print('==> تم تصحيح السجل لـ $newRowId وحذف القديم.');
          } catch (e) {
            print('==> خطأ أثناء التصحيح: $e');
          }
        }
      }
    }

    print('----------------------------------------');
    print('الخلاصة:');
    print('- السجلات المعكوسة: ${suspiciousDocs.length}');
    print('- السجلات التي تم/سيتم تصحيحها (لا يوجد لها تكرار): $willCorrectCount');

  } catch(e) {
    print('Error: $e');
  }
}
