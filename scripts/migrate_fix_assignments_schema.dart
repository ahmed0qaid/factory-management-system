import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  final endpoint = 'https://fra.cloud.appwrite.io/v1';
  final projectId = '6a6a49d1000884049205';
  final databaseId = 'hr';
  final apiKey = 'standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93';

  final client = Client()
    ..setEndpoint(endpoint)
    ..setProject(projectId)
    ..setKey(apiKey);

  final db = Databases(client);

  // Fields to DELETE from employee_shift_assignments (they don't belong here)
  final fieldsToDelete = ['shift_id', 'created_at'];

  print('========================================');
  print('  Migration: Fix employee_shift_assignments');
  print('========================================');
  print('');

  for (final field in fieldsToDelete) {
    print('Deleting "$field" from employee_shift_assignments...');
    try {
      await db.deleteAttribute(
        databaseId: databaseId,
        collectionId: 'employee_shift_assignments',
        key: field,
      );
      print('  [OK] Deleted "$field" successfully.');
    } catch (e) {
      print('  [ERROR] Failed to delete "$field": $e');
    }
    // Small delay to let Appwrite process
    await Future.delayed(Duration(seconds: 2));
  }

  print('');
  print('Migration complete. Run audit again to verify.');
}
