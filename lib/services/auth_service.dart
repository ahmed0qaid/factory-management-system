import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import 'appwrite_service.dart';

class AuthService {
  Future<void> signInWithEmployeeNumber({
    required String employeeNumber,
    required String password,
  }) async {
    final email =
        '${employeeNumber.trim().toLowerCase()}@${AppConstants.technicalEmailDomain}';
    print('Login technical email: $email');
    await AppwriteService.account.createEmailPasswordSession(
      email: email,
      password: password,
    );
  }

  Future<void> changeTemporaryPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await AppwriteService.account.get();
    await AppwriteService.account.updatePassword(
      password: newPassword,
      oldPassword: oldPassword,
    );
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: user.$id,
      data: {'must_change_password': false},
    );
  }

  Future<void> signOut() =>
      AppwriteService.account.deleteSession(sessionId: 'current');

  Future<models.User> getCurrentUser() => AppwriteService.account.get();
}
