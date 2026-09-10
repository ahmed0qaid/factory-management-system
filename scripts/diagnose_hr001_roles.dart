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

  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];

  if (projectId == null) return;

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId);

  final account = Account(client);

  try {
    print('Attempting login as hr001...');
    await account.createEmailPasswordSession(
      email: 'hr001@hr.local',
      password: 'password123',
    );
  } catch (e) {
    try {
      await account.createEmailPasswordSession(
        email: 'hr001@hr.local',
        password: '12345678',
      );
    } catch (e2) {
      print('Login failed: ' + e2.toString());
      return;
    }
  }

  try {
    final user = await account.get();
    print('User accessed. ID: ' + user.$id);
    print('Email: ' + user.email);
    // Print sessions to see if there's any anomaly
    final sessions = await account.listSessions();
    print('Active Sessions: ' + sessions.total.toString());
  } catch (e) {
    print('Failed to get user: ' + e.toString());
  }
}
