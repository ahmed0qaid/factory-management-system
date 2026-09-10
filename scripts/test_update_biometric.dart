import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('678ba6e8000305a415ff')
    ..setKey(dotenv.env['APPWRITE_API_KEY']!);

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

    final docId = docs.documents.first.$id;
    print('EMP005 ID: $docId');

    final updated = await db.updateDocument(
      databaseId: 'hr_erp_db',
      collectionId: 'profiles',
      documentId: docId,
      data: {'biometric_employee_id': '40'},
    );
    print('Updated successfully: ${updated.data['biometric_employee_id']}');
  } catch (e) {
    print('Error: $e');
  }
}
