import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';

/// Configures fund tables for row-level, company-scoped permissions.
///
/// Required environment variables:
/// APPWRITE_ENDPOINT
/// APPWRITE_PROJECT_ID
/// APPWRITE_API_KEY
/// APPWRITE_DATABASE_ID (optional, defaults to hr)
/// APPWRITE_COMPANY_TEAM_IDS (comma-separated Appwrite Team IDs)
///
/// This script intentionally contains no credentials and grants no broad
/// read/update/delete access at table level. Each fund row is expected to carry
/// its company-specific document permissions from FundService.
Future<void> main() async {
  final endpoint = Platform.environment['APPWRITE_ENDPOINT'];
  final projectId = Platform.environment['APPWRITE_PROJECT_ID'];
  final apiKey = Platform.environment['APPWRITE_API_KEY'];
  final databaseId = Platform.environment['APPWRITE_DATABASE_ID'] ?? 'hr';
  final teamIds = (Platform.environment['APPWRITE_COMPANY_TEAM_IDS'] ?? '')
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  if (endpoint == null || projectId == null || apiKey == null) {
    stderr.writeln(
      'Missing APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, or APPWRITE_API_KEY.',
    );
    exitCode = 2;
    return;
  }
  if (teamIds.isEmpty) {
    stderr.writeln('APPWRITE_COMPANY_TEAM_IDS must contain at least one team.');
    exitCode = 2;
    return;
  }

  final client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
  final databases = Databases(client);

  final createPermissions = <String>[];
  for (final teamId in teamIds) {
    createPermissions
      ..add(Permission.create(Role.team(teamId, 'hr_admin')))
      ..add(Permission.create(Role.team(teamId, 'financial_manager')));
  }

  for (final table in const [
    'funds',
    'fund_transactions',
    'fund_closures',
  ]) {
    try {
      stdout.writeln('Updating permissions for $table...');
      await databases.updateCollection(
        databaseId: databaseId,
        collectionId: table,
        name: table,
        permissions: createPermissions,
        documentSecurity: true,
        enabled: true,
      );
      stdout.writeln('Successfully updated $table.');
    } catch (error) {
      stderr.writeln('Error with $table: $error');
      exitCode = 1;
    }
  }
}
