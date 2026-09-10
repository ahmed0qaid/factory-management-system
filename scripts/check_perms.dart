import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

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

  final client = Client()
    ..setEndpoint(env['APPWRITE_ENDPOINT']!)
    ..setProject(env['APPWRITE_PROJECT_ID']!)
    ..setKey(env['APPWRITE_API_KEY']!);

  final db = Databases(client);
  try {
    final c = await db.getCollection(
      databaseId: env['APPWRITE_DATABASE_ID']!,
      collectionId: 'temporary_biometric_employees',
    );
    print('Permissions: ${c.$permissions}');
    print('DocSecurity: ${c.documentSecurity}');
  } catch (e) {
    print('Error: $e');
  }
}
