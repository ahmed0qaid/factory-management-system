import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6a6a49d1000884049205')
      .setKey('standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93');

  Databases databases = Databases(client);
  final databaseId = 'hr';

  final collectionsToUpdate = [
    'profiles',
    'attendance_records',
    'advances',
    'penalties',
    'leave_requests',
    'factory_stoppages',
    'overtime_records',
    'payroll_records',
  ];

  for (final table in collectionsToUpdate) {
    try {
      final collection = await databases.getCollection(
        databaseId: databaseId,
        collectionId: table,
      );
      
      print('--- $table ---');
      print('Current documentSecurity: ${collection.documentSecurity}');
      print('Current permissions: ${collection.$permissions}');
    } catch (e) {
      print('Error with $table: $e');
    }
  }
}
