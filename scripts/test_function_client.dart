import 'dart:convert';
import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final endpoint = 'https://fra.cloud.appwrite.io/v1';
  final projectId = '6a6a49d1000884049205';

  final client = Client().setEndpoint(endpoint).setProject(projectId);

  final account = Account(client);
  final functions = Functions(client);
  final databases = Databases(client);

  try {
    print('Logging in as HR Admin (hr001@hr.local)...');
    await account.createEmailPasswordSession(
      email: 'hr001@hr.local',
      password: '12345678',
    );
    final jwt = await account.createJWT();
    client.setJWT(jwt.jwt);
    print('Logged in and JWT set successfully!');

    // Test 1: With Biometric ID
    print('\n--- Test 1: With Biometric ID (BIO901) ---');
    final body1 = jsonEncode({
      'employeeNumber': 'BIO903',
      'fullName': 'Test Bio 903',
      'temporaryPassword': 'password123',
      'role': 'employee',
      'biometricEmployeeId': 'BIO903',
    });

    try {
      final res1 = await functions.createExecution(
        functionId: 'create_employee',
        body: body1,
        xasync: false,
      );
      print('Execution Status: ${res1.status}');
      print('Execution Response: ${res1.responseBody}');
    } catch (e) {
      print('Execution failed: $e');
    }

    // Check DB
    final docs1 = await databases.listDocuments(
      databaseId: 'hr',
      collectionId: 'profiles',
      queries: [Query.equal('employee_number', 'BIO903')],
    );
    if (docs1.documents.isNotEmpty) {
      final doc = docs1.documents.first.data;
      print(
        "FOUND IN PROFILES: name=${doc['full_name']}, biometric_employee_id=${doc['biometric_employee_id']}",
      );
    } else {
      print('NOT FOUND in DB');
    }

    // Test 2: Without Biometric ID
    print('\n--- Test 2: Without Biometric ID (NOBIO904) ---');
    final body2 = jsonEncode({
      'employeeNumber': 'NOBIO904',
      'fullName': 'Test NoBio 904',
      'temporaryPassword': 'password123',
      'role': 'employee',
    });

    try {
      final res2 = await functions.createExecution(
        functionId: 'create_employee',
        body: body2,
        xasync: false,
      );
      print('Execution Status: ${res2.status}');
      print('Execution Response: ${res2.responseBody}');
    } catch (e) {
      print('Execution failed: $e');
    }

    // Check DB
    final docs2 = await databases.listDocuments(
      databaseId: 'hr',
      collectionId: 'profiles',
      queries: [Query.equal('employee_number', 'NOBIO904')],
    );
    if (docs2.documents.isNotEmpty) {
      final doc = docs2.documents.first.data;
      print(
        "FOUND IN PROFILES: name=${doc['full_name']}, biometric_employee_id=${doc['biometric_employee_id']}",
      );
    } else {
      print('NOT FOUND in DB');
    }
  } catch (e) {
    print('Error: $e');
  }
}
