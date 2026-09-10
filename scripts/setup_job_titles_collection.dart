import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6a6a49d1000884049205')
      .setKey('standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93');

  Databases databases = Databases(client);
  final databaseId = 'hr';

  try {
    final collection = await databases.getCollection(
      databaseId: databaseId,
      collectionId: 'job_titles',
    );
    print('Collection exists: ${collection.name}');
  } catch (e) {
    if (e.toString().contains('collection_not_found')) {
      print('Collection job_titles does not exist. Creating it...');
      try {
        await databases.createCollection(
          databaseId: databaseId,
          collectionId: 'job_titles',
          name: 'Job Titles',
          permissions: [
            'read("team:company_main")',
            'create("team:company_main/hr_admin")',
            'update("team:company_main/hr_admin")',
            'delete("team:company_main/hr_admin")',
          ],
          documentSecurity: false,
        );
        print('Created collection job_titles');
        
        await databases.createStringAttribute(
          databaseId: databaseId,
          collectionId: 'job_titles',
          key: 'company_id',
          size: 100,
          xrequired: true,
        );
        await databases.createStringAttribute(
          databaseId: databaseId,
          collectionId: 'job_titles',
          key: 'name',
          size: 255,
          xrequired: true,
        );
        await databases.createBooleanAttribute(
          databaseId: databaseId,
          collectionId: 'job_titles',
          key: 'active',
          xrequired: false,
          xdefault: true,
        );
        await databases.createStringAttribute(
          databaseId: databaseId,
          collectionId: 'job_titles',
          key: 'description',
          size: 500,
          xrequired: false,
        );
        print('Added attributes to job_titles');
        // Indexes
        // Note: Attribute creation is async on server side, we might need to wait before creating indexes.
        // We'll skip index creation in this script for safety and do it manually if needed, or wait.
      } catch (createError) {
        print('Error creating collection: $createError');
      }
    } else {
      print('Error: $e');
    }
  }
}
