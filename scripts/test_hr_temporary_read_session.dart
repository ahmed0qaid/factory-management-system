import 'dart:io';
import 'package:dart_appwrite/dart_appwrite.dart';

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
  final databaseId = env['APPWRITE_DATABASE_ID'];

  if (projectId == null || databaseId == null) {
    print('Missing Appwrite variables in .env');
    exit(1);
  }

  final client = Client().setEndpoint(endpoint).setProject(projectId);

  final account = Account(client);
  final databases = Databases(client);

  try {
    print('Logging in as HR001...');
    await account.createEmailPasswordSession(
      email: 'hr001@example.com',
      password: 'password123',
    );
    print('Login successful.');

    final statuses = ['pending', 'linked', 'approved', 'rejected'];

    for (var status in statuses) {
      final res = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'temporary_biometric_employees',
        queries: [Query.equal('status', status)],
      );
      print('HR001 sees ${res.total} rows with status = $status');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (e) {}
  }
}
