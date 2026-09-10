import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  // CONFIGURATION
  final bool dryRun = false; 
  // Set to false ONLY when ready to actually write to the database
  
  print('--- MIGRATION SCRIPT STARTED ---');
  print('Dry Run Mode: $dryRun');

  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6a6a49d1000884049205')
      .setKey('standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93');

  Databases databases = Databases(client);
  final databaseId = 'hr';

  try {
    // 1. Read all profiles
    int offset = 0;
    int limit = 100;
    List<Map<String, dynamic>> allProfiles = [];
    
    while (true) {
      final res = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: 'profiles',
        queries: [
          Query.limit(limit),
          Query.offset(offset),
        ],
      );
      
      for (var doc in res.documents) {
        allProfiles.add({...doc.data, '\$id': doc.$id});
      }
      
      if (res.documents.length < limit) break;
      offset += limit;
    }
    
    print('Total profiles fetched: ${allProfiles.length}');

    // 2. Collect distinct non-empty job_title_name values per company
    // Structure: company_id -> Set of job_title_names
    Map<String, Set<String>> distinctTitlesPerCompany = {};
    int profilesWithTitles = 0;

    for (var profile in allProfiles) {
      final companyId = profile['company_id']?.toString() ?? '';
      final titleName = profile['job_title_name']?.toString().trim() ?? '';
      
      if (companyId.isNotEmpty && titleName.isNotEmpty) {
        profilesWithTitles++;
        distinctTitlesPerCompany.putIfAbsent(companyId, () => {});
        distinctTitlesPerCompany[companyId]!.add(titleName);
      }
    }

    print('Profiles with non-empty job titles: $profilesWithTitles');
    
    // Total unique titles across all companies
    int totalUniqueTitles = distinctTitlesPerCompany.values.fold(0, (sum, set) => sum + set.length);
    print('Total unique job titles to process: $totalUniqueTitles');

    // 3. For each title, create if not exists
    // We'll keep a map of "company_id|title_name" to "job_title_id"
    Map<String, String> titleToIdMap = {};
    int titlesCreated = 0;
    int titlesFound = 0;

    for (var companyId in distinctTitlesPerCompany.keys) {
      for (var titleName in distinctTitlesPerCompany[companyId]!) {
        // Check if exists
        final existing = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: 'job_titles',
          queries: [
            Query.equal('company_id', companyId),
            Query.equal('name', titleName),
          ],
        );

        if (existing.documents.isNotEmpty) {
          titlesFound++;
          final existingId = existing.documents.first.$id;
          titleToIdMap['$companyId|$titleName'] = existingId;
        } else {
          titlesCreated++;
          final newId = ID.unique();
          titleToIdMap['$companyId|$titleName'] = newId;
          
          if (!dryRun) {
            await databases.createDocument(
              databaseId: databaseId,
              collectionId: 'job_titles',
              documentId: newId,
              data: {
                'company_id': companyId,
                'name': titleName,
                'active': true,
              },
            );
            print('  -> Created job title: $titleName (ID: $newId)');
          } else {
            print('  -> [DryRun] Would create job title: $titleName (ID: $newId)');
          }
        }
      }
    }
    
    print('Job Titles summary: $titlesFound existing found, $titlesCreated new titles to create.');

    // 4. Update profiles with the correct job_title_id
    int profilesUpdated = 0;
    for (var profile in allProfiles) {
      final companyId = profile['company_id']?.toString() ?? '';
      final titleName = profile['job_title_name']?.toString().trim() ?? '';
      final currentTitleId = profile['job_title_id']?.toString() ?? '';
      
      if (companyId.isNotEmpty && titleName.isNotEmpty) {
        final targetId = titleToIdMap['$companyId|$titleName'];
        
        if (targetId != null && currentTitleId != targetId) {
          profilesUpdated++;
          if (!dryRun) {
            await databases.updateDocument(
              databaseId: databaseId,
              collectionId: 'profiles',
              documentId: profile['\$id'],
              data: {
                'job_title_id': targetId,
              },
            );
          }
        }
      }
    }
    
    print('Profiles to update with job_title_id: $profilesUpdated');
    
    print('--- MIGRATION SCRIPT FINISHED ---');
    if (dryRun) {
      print('NOTE: This was a Dry Run. No changes were saved to the database.');
    } else {
      print('NOTE: Changes have been successfully applied to the database.');
    }
    
  } catch (e) {
    print('Error during migration: $e');
  }
}
