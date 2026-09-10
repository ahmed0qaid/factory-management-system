import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Use manual env loading since flutter_dotenv requires flutter
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final apiKey = env['APPWRITE_API_KEY'];

  if (projectId == null || apiKey == null) {
    print('Missing Appwrite config');
    return;
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);

  try {
    final docs = await db.listDocuments(
      databaseId: 'hr_erp_db',
      collectionId: 'profiles',
      queries: [Query.equal('employee_number', 'EMP005')],
    );

    if (docs.documents.isEmpty) {
      print('EMP005 not found');
      return;
    }

    final doc = docs.documents.first;
    print(
      'Found EMP005. ID: ${doc.$id}, Current Biometric ID: ${doc.data['biometric_employee_id']}',
    );

    final updated = await db.updateDocument(
      databaseId: 'hr_erp_db',
      collectionId: 'profiles',
      documentId: doc.$id,
      data: {'biometric_employee_id': '40'},
    );
    print('Update response: ${updated.data['biometric_employee_id']}');

    final readAgain = await db.getDocument(
      databaseId: 'hr_erp_db',
      collectionId: 'profiles',
      documentId: doc.$id,
    );
    print('Read again: ${readAgain.data['biometric_employee_id']}');
  } catch (e) {
    if (e is AppwriteException) {
      print('Appwrite Error: ${e.message} (Code: ${e.code})');
    } else {
      print('Error: $e');
    }
  }
}
