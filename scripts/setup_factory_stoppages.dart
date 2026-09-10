import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dart_appwrite/models.dart' hide File;
import 'package:dart_appwrite/enums.dart';
import 'dart:io';

Future<void> main() async {
  var endpoint = Platform.environment['APPWRITE_ENDPOINT'];
  var projectId = Platform.environment['APPWRITE_PROJECT_ID'];
  var apiKey = Platform.environment['APPWRITE_API_KEY'];
  var databaseId = Platform.environment['APPWRITE_DATABASE_ID'];

  if (endpoint == null) {
    try {
      final env = File('.env').readAsStringSync();
      for (var line in env.split('\n')) {
        if (line.startsWith('APPWRITE_ENDPOINT='))
          endpoint = line.split('=')[1].trim();
        if (line.startsWith('APPWRITE_PROJECT_ID='))
          projectId = line.split('=')[1].trim();
        if (line.startsWith('APPWRITE_API_KEY='))
          apiKey = line.split('=')[1].trim();
        if (line.startsWith('APPWRITE_DATABASE_ID='))
          databaseId = line.split('=')[1].trim();
      }
    } catch (e) {
      print('Could not read .env file');
    }
  }

  if (endpoint == null ||
      projectId == null ||
      apiKey == null ||
      databaseId == null) {
    print('Missing Appwrite environment variables.');
    exit(1);
  }

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final databases = Databases(client);
  final tableId = 'factory_stoppages';

  try {
    print('Creating collection: \$tableId');
    await databases.createCollection(
      databaseId: databaseId,
      collectionId: tableId,
      name: 'Factory Stoppages',
      permissions: [
        Permission.read(Role.users()),
        Permission.create(Role.team('company_main')),
        Permission.create(Role.team('hr_admin')),
        Permission.update(Role.team('company_main')),
        Permission.update(Role.team('hr_admin')),
        Permission.delete(Role.team('company_main')),
        Permission.delete(Role.team('hr_admin')),
      ],
      documentSecurity: true,
    );

    print('Creating attributes...');
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'company_id',
      size: 36,
      xrequired: true,
    );
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'title',
      size: 160,
      xrequired: true,
    );
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'reason',
      size: 1000,
      xrequired: false,
    );
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'start_date',
      xrequired: true,
    );
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'end_date',
      xrequired: true,
    );
    await databases.createBooleanAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'is_paid',
      xrequired: true,
    );
    await databases.createStringAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'created_by',
      size: 80,
      xrequired: false,
    );
    await databases.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'created_at',
      xrequired: true,
    );

    print('Waiting for attributes to be created...');
    await Future.delayed(Duration(seconds: 5));

    print('Creating index...');
    await databases.createIndex(
      databaseId: databaseId,
      collectionId: tableId,
      key: 'factory_stoppages_period_idx',
      type: DatabasesIndexType.key,
      attributes: ['company_id', 'start_date'],
    );

    print('Successfully created table \$tableId');
  } catch (e) {
    print('Error: \$e');
  }
}
