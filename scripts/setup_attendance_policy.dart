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
  final collectionId = 'attendance_policies';

  try {
    try {
      await databases.deleteCollection(
        databaseId: databaseId,
        collectionId: collectionId,
      );
      print('Deleted existing table.');
    } catch (_) {}

    try {
      print('Creating collection: ' + collectionId);
      await databases.createCollection(
        databaseId: databaseId,
        collectionId: collectionId,
        name: 'Attendance Policies',
        documentSecurity: true,
        permissions: [
          Permission.read(Role.users()),
          Permission.create(Role.team('company_main')),
          Permission.update(Role.team('company_main')),
          Permission.delete(Role.team('company_main')),
        ],
      );
      print('Table created successfully.');

      print('Creating attributes for ' + collectionId);

      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'company_id',
        size: 36,
        xrequired: true,
      );
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'name',
        size: 120,
        xrequired: true,
      );
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'grace_late_minutes',
        xrequired: false,
        xdefault: 15,
      );
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'grace_early_leave_minutes',
        xrequired: false,
        xdefault: 10,
      );
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'late_calculation_mode',
        size: 40,
        xrequired: true,
      );
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'early_leave_calculation_mode',
        size: 40,
        xrequired: true,
      );
      await databases.createIntegerAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'overtime_minimum_minutes',
        xrequired: false,
        xdefault: 30,
      );
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'overtime_requires_hr_approval',
        xrequired: false,
        xdefault: true,
      );
      await databases.createBooleanAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'active',
        xrequired: true,
      );
      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'created_at',
        xrequired: true,
      );
      await databases.createDatetimeAttribute(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'updated_at',
        xrequired: false,
      );

      print('Waiting for attributes to be ready...');
      await Future.delayed(const Duration(seconds: 5));

      print('Creating indexes for ' + collectionId);
      await databases.createIndex(
        databaseId: databaseId,
        collectionId: collectionId,
        key: 'active_idx',
        type: DatabasesIndexType.key,
        attributes: ['company_id', 'active'],
      );

      print('Waiting for indexes to be ready...');
      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      if (e is AppwriteException && e.code == 409) {
        print(
          'Table ' +
              collectionId +
              ' already exists. Proceeding to add default policy...',
        );
      } else {
        rethrow;
      }
    }

    final docs = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: [
        Query.equal('company_id', 'company_main'),
        Query.equal('active', true),
      ],
    );

    if (docs.total == 0) {
      print('Creating default active policy...');
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: 'default_policy',
        data: {
          'company_id': 'company_main',
          'name': 'السياسة الافتراضية للدوام',
          'grace_late_minutes': 15,
          'grace_early_leave_minutes': 10,
          'late_calculation_mode': 'full_time',
          'early_leave_calculation_mode': 'full_time',
          'overtime_minimum_minutes': 30,
          'overtime_requires_hr_approval': true,
          'active': true,
          'created_at': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.users()),
          Permission.update(Role.team('company_main')),
        ],
      );
      print('Default policy created successfully.');
    } else {
      print('A default active policy already exists.');
    }

    final attendanceTable = 'attendance_records';
    print('Checking missing fields in ' + attendanceTable);
    try {
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: attendanceTable,
        key: 'attendance_issue_type',
        size: 50,
        xrequired: false,
      );
    } catch (_) {}
    try {
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: attendanceTable,
        key: 'review_note',
        size: 1000,
        xrequired: false,
      );
    } catch (_) {}
    try {
      await databases.createStringAttribute(
        databaseId: databaseId,
        collectionId: attendanceTable,
        key: 'review_status',
        size: 50,
        xrequired: false,
      );
    } catch (_) {}

    print('Setup completed.');
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
