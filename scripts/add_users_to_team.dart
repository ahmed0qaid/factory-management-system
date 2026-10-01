import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';

Map<String, String> _readEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};

  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    values[key] = value;
  }
  return values;
}

String _configValue(Map<String, String> fileEnv, String key) {
  return Platform.environment[key]?.trim().isNotEmpty == true
      ? Platform.environment[key]!.trim()
      : (fileEnv[key]?.trim() ?? '');
}

Future<void> main() async {
  final fileEnv = _readEnvFile('.env');
  final endpoint = _configValue(fileEnv, 'APPWRITE_ENDPOINT');
  final projectId = _configValue(fileEnv, 'APPWRITE_PROJECT_ID');
  final apiKey = _configValue(fileEnv, 'APPWRITE_API_KEY');
  final teamId = _configValue(fileEnv, 'APPWRITE_COMPANY_TEAM_ID').isNotEmpty
      ? _configValue(fileEnv, 'APPWRITE_COMPANY_TEAM_ID')
      : 'company_main';

  if (endpoint.isEmpty || projectId.isEmpty || apiKey.isEmpty) {
    stderr.writeln(
      'Missing APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, or APPWRITE_API_KEY. '
      'Provide them through environment variables or a local .env file.',
    );
    exitCode = 1;
    return;
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final teams = Teams(client);
  final users = Users(client);

  try {
    final allUsers = await users.list();
    stdout.writeln('Found ${allUsers.total} users.');

    for (final user in allUsers.users) {
      if (user.email.startsWith('hr')) continue;
      try {
        await teams.createMembership(
          teamId: teamId,
          email: user.email,
          roles: const ['employee'],
          url: 'http://localhost',
          name: user.name,
        );
        stdout.writeln('Added ${user.email} to team $teamId');
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('already a member') ||
            message.contains('already exists')) {
          stdout.writeln('${user.email} is already in team $teamId');
        } else {
          stderr.writeln('Error adding ${user.email}: $error');
        }
      }
    }
  } catch (error) {
    stderr.writeln('Unable to synchronize team memberships: $error');
    exitCode = 1;
  }
}
