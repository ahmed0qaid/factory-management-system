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
    final titlesRes = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'job_titles',
      queries: [Query.limit(100)],
    );
    print('Total job titles in collection: ${titlesRes.total}');
    
    int offset = 0;
    int limit = 100;
    List<Map<String, dynamic>> allProfiles = [];
    
    while (true) {
      final res = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'profiles',
        queries: [Query.limit(limit), Query.offset(offset)],
      );
      
      for (var doc in res.documents) {
        allProfiles.add({...doc.data, '\$id': doc.$id});
      }
      if (res.documents.length < limit) break;
      offset += limit;
    }
    
    int withId = 0;
    int withoutId = 0;
    for (var p in allProfiles) {
      if (p['job_title_id'] != null && p['job_title_id'].toString().trim().isNotEmpty) {
        withId++;
      } else {
        withoutId++;
      }
    }
    
    print('Profiles with job_title_id: $withId');
    print('Profiles without job_title_id: $withoutId');
    print('\nExamples (first 5 profiles):');
    
    for (int i = 0; i < allProfiles.length && i < 5; i++) {
      final p = allProfiles[i];
      print('- EmpNum: ${p['employee_number']} | TitleName: ${p['job_title_name']} | TitleID: ${p['job_title_id']}');
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
