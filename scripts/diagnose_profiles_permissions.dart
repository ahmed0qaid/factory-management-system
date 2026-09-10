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
  final apiKey = env['APPWRITE_API_KEY'];
  final databaseId = env['APPWRITE_DATABASE_ID'] ?? 'hr';

  if (projectId == null || apiKey == null) {
    print('Missing Appwrite config');
    return;
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);
  final teams = Teams(client);

  print('=====================================');
  print('1. EMP005 Permissions Check');
  print('=====================================');
  try {
    final docs = await db.listDocuments(
      databaseId: databaseId,
      collectionId: 'profiles',
      queries: [Query.equal('employee_number', 'EMP005')],
    );
    if (docs.documents.isEmpty) {
      print('EMP005 not found!');
    } else {
      final emp = docs.documents.first;
      print('rowId / \$id: ${emp.$id}');
      print('employee_number: ${emp.data['employee_number']}');
      print('full_name: ${emp.data['full_name']}');
      print('biometric_employee_id: ${emp.data['biometric_employee_id']}');
      print('permissions: ${emp.$permissions}');
    }
  } catch (e) {
    print('Error reading EMP005: $e');
  }

  print('\n=====================================');
  print('2. HR001 Team Membership Check');
  print('=====================================');
  try {
    final memberships = await teams.listMemberships(teamId: 'company_main');
    print('Total memberships in company_main: ${memberships.total}');
    for (var m in memberships.memberships) {
      print('- userId: ${m.userId}');
      print('  userEmail: ${m.userEmail}');
      print(
        '  status: ${m.confirm ? "accepted/active" : "pending/unconfirmed"}',
      );
      print('  roles: ${m.roles}');
      print('-----------------------------');
    }
  } catch (e) {
    print('Error reading memberships: $e');
  }
}
