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

  final targetCollections = [
    'employee_shift_assignments',
    'employee_work_schedules',
  ];

  print('==================================================');
  print('  CLEARING WORK SCHEDULE DATA (ROWS ONLY) ');
  print('==================================================');
  
  Map<String, int> initialCounts = {};

  // 1. Get initial counts
  for (final collectionId in targetCollections) {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: [Query.limit(1)], // Just to get total
      );
      initialCounts[collectionId] = response.total;
    } catch (e) {
      print('Error getting count for $collectionId: $e');
      initialCounts[collectionId] = 0;
    }
  }

  print('');
  print('سيتم حذف:');
  for (final collectionId in targetCollections) {
    print('$collectionId: ${initialCounts[collectionId]} rows');
  }
  print('');

  // 2. Delete rows with pagination
  for (final collectionId in targetCollections) {
    print('Deleting rows in $collectionId...');
    int deletedCount = 0;
    bool hasMore = true;

    while (hasMore) {
      try {
        final response = await db.listDocuments(
          databaseId: databaseId,
          collectionId: collectionId,
          queries: [Query.limit(100)],
        );

        if (response.documents.isEmpty) {
          hasMore = false;
          break;
        }

        for (final doc in response.documents) {
          await db.deleteDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: doc.$id,
          );
          deletedCount++;
        }
        print('  Deleted $deletedCount/${initialCounts[collectionId]} rows so far...');
      } catch (e) {
        print('  Error during deletion in $collectionId: $e');
        break; // Stop loop on error
      }
    }
    print('Finished deleting rows in $collectionId. Total deleted: $deletedCount');
    print('');
  }

  // 3. Verify deletion
  print('==================================================');
  print('  VERIFICATION');
  print('==================================================');
  
  for (final collectionId in targetCollections) {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: [Query.limit(1)],
      );
      print('Count after deletion in $collectionId: ${response.total}');
    } catch (e) {
      print('Error verifying count for $collectionId: $e');
    }
  }

  print('');
  print('Done.');
}
