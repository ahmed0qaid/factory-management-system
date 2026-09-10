import 'package:dart_appwrite/dart_appwrite.dart';

void main() async {
  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6a6a49d1000884049205')
      .setKey('standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93');

  Databases databases = Databases(client);
  Users users = Users(client);

  try {
    final docs = await databases.listDocuments(
      databaseId: 'hr',
      collectionId: 'profiles',
      queries: [Query.equal('employee_number', '9')],
    );

    if (docs.total == 0) {
      print('لا يوجد profile للموظف رقم 9');
      return;
    }

    final profile = docs.documents.first;
    final profileId = profile.$id;
    print('--- Profile Data ---');
    print('profileId: $profileId');
    print('employee_number: ${profile.data["employee_number"]}');
    print('full_name: ${profile.data["full_name"]}');
    print('role: ${profile.data["role"]}');
    print('active: ${profile.data["active"]}');
    print('must_change_password: ${profile.data["must_change_password"]}');
    print('company_id: ${profile.data["company_id"]}');
    
    // Check user in Auth
    final userId = profileId; // Appwrite typically uses profileId as userId in this project structure
    print('--- Auth User Data ---');
    print('userId: $userId');
    try {
      final user = await users.get(userId: userId);
      print('email: ${user.email}');
      print('name: ${user.name}');
      print('status: ${user.status}');
      
      final appEmail = '9@hr.local';
      print('loginEmailForEmployeeNumber9 = $appEmail');
      print('Auth Email == App Generated Email: ${user.email == appEmail}');
    } catch (e) {
      print('Failed to get user from Auth: $e');
    }
  } catch (e) {
    print('Error: $e');
  }
}
