import 'package:dart_appwrite/dart_appwrite.dart';
import 'dart:io';

void main() async {
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

  final endpoint = env['APPWRITE_ENDPOINT']!;
  final projectId = env['APPWRITE_PROJECT_ID']!;
  final apiKey = env['APPWRITE_API_KEY']!;
  final dbId = env['APPWRITE_DATABASE_ID']!;

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);

  final collectionsToCheck = [
    'attendance_records',
    'overtime_records',
    'biometric_logs',
    'biometric_import_batches',
    'notifications',
    'profiles',
  ];

  for (var c in collectionsToCheck) {
    try {
      final collection = await db.getCollection(
        databaseId: dbId,
        collectionId: c,
      );
      print('=== Collection: \$c ===');
      for (var attr in collection.attributes) {
        final map = attr.toMap();
        print('- ${map['key']} (${map['type']}, required: ${map['required']})');
      }
    } on AppwriteException catch (e) {
      print('Collection \$c error: \${e.message}');
    }
  }
}
