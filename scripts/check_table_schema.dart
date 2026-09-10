import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  final client = Client()
      .setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
      .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
      .setKey(dotenv.env['APPWRITE_API_KEY']!);

  final databases = Databases(client);
  final dbId = dotenv.env['APPWRITE_DATABASE_ID']!;

  final tables = [
    'attendance_records',
    'overtime_records',
    'biometric_logs',
    'biometric_import_batches',
    'notifications',
    'temporary_biometric_employees',
  ];

  for (final tableId in tables) {
    try {
      print('\n--- Schema for \$tableId ---');
      final attrs = await databases.listAttributes(
        databaseId: dbId,
        collectionId: tableId,
      );

      for (final attr in attrs.attributes) {
        // Appwrite models.Attribute doesn't have a direct toMap(),
        // but we can inspect it. We'll cast to dynamic and access properties.
        final a = attr as dynamic;
        try {
          print(
            '- Key: \${a.key}, Type: \${a.type}, Required: \${a.isRequired}, Default: \${a.xdefault}',
          );
        } catch (_) {
          // Some attributes might not have xdefault based on type (like datetime).
          print(
            '- Key: \${a.key}, Type: \${a.type}, Required: \${a.isRequired}',
          );
        }
      }
    } catch (e) {
      print('Error checking \$tableId: \$e');
    }
  }
}
