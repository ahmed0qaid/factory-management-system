import 'package:dart_appwrite/dart_appwrite.dart';
import '../lib/config/constants.dart';
import 'dart:io';
import 'setup_db.dart';

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

  final db = Databases(client);
  final storage = Storage(client);

  print('Setting up employee_documents table...');
  try {
    await db.createCollection(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      name: 'Employee Documents',
      permissions: [
        Permission.read(Role.team('company_main')),
        Permission.create(Role.team('company_main', 'hr_admin')),
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
      ],
    );
    print('Created employee_documents collection.');

    await Future.delayed(const Duration(seconds: 1));

    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'company_id',
      size: 36,
      xrequired: true,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'employee_id',
      size: 80,
      xrequired: true,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'document_type',
      size: 80,
      xrequired: true,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'title',
      size: 160,
      xrequired: true,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'file_id',
      size: 160,
      xrequired: false,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'file_name',
      size: 255,
      xrequired: false,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'file_path',
      size: 255,
      xrequired: false,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'notes',
      size: 500,
      xrequired: false,
    );
    await db.createStringAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'uploaded_by',
      size: 80,
      xrequired: true,
    );
    await db.createDatetimeAttribute(
      databaseId: databaseId,
      collectionId: 'employee_documents',
      key: 'created_at',
      xrequired: true,
    );

    print('Attributes created for employee_documents.');
  } catch (e) {
    print('Error creating employee_documents table (might already exist): $e');
  }

  print('Setting up employee_documents storage bucket...');
  try {
    await storage.createBucket(
      bucketId: 'employee_documents',
      name: 'Employee Documents',
      permissions: [
        Permission.read(Role.team('company_main')),
        Permission.create(Role.team('company_main', 'hr_admin')),
        Permission.update(Role.team('company_main', 'hr_admin')),
        Permission.delete(Role.team('company_main', 'hr_admin')),
      ],
      fileSecurity: true, // Allow file-level security
    );
    print('Bucket employee_documents created.');
  } catch (e) {
    print('Error creating bucket (might already exist): $e');
  }

  print('Setup complete.');
}
