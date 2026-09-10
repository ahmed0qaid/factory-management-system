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

  if (projectId == null || apiKey == null) {
    print('Missing Appwrite config');
    return;
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final teams = Teams(client);

  print('=====================================');
  print('Fixing HR001 Roles');
  print('=====================================');
  try {
    final memberships = await teams.listMemberships(teamId: 'company_main');

    for (var m in memberships.memberships) {
      if (m.userEmail == 'hr001@hr.local') {
        print(
          'Found hr001@hr.local. Membership ID: \${m.\$id}, Current Roles: \${m.roles}',
        );

        try {
          final updated = await teams.updateMembership(
            teamId: 'company_main',
            membershipId: m.$id,
            roles: ['hr_admin'],
          );
          print('Successfully updated hr001 roles to: \${updated.roles}');
        } catch (e) {
          print(
            'Failed to update membership roles. Attempting via teams.updateMembershipRoles... Error was: \$e',
          );
        }
      }
    }
  } catch (e) {
    print('Error: \$e');
  }
}
