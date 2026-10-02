import 'dart:convert';

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
    await AppwriteService.account.createEmailPasswordSession(
      email: email,
      password: password,
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await AppwriteService.account.updatePassword(
      password: newPassword,
      oldPassword: oldPassword,
    );
  }

  Future<void> changeTemporaryPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await AppwriteService.account.get();
    await changePassword(oldPassword: oldPassword, newPassword: newPassword);

    final execution = await AppwriteService.functions.createExecution(
      functionId: AppConstants.updateEmployeeCredentialsFunctionId,
      body: jsonEncode({
        'profileId': user.$id,
        'action': 'completeOwnPasswordChange',
      }),
      xasync: false,
    );

    if (execution.status.name.toLowerCase() != 'completed') {
      throw Exception(
        execution.errors.isNotEmpty
            ? execution.errors
            : 'تعذر إكمال تحديث حالة كلمة المرور',
      );
    }

    final response = jsonDecode(
      execution.responseBody.isEmpty ? '{}' : execution.responseBody,
    );
    if (response is Map && response['success'] != true) {
      throw Exception(
        response['error'] ?? 'تعذر إكمال تحديث حالة كلمة المرور',
      );
    }
  }

  Future<void> signOut() =>
      AppwriteService.account.deleteSession(sessionId: 'current');

  Future<models.User> getCurrentUser() => AppwriteService.account.get();
}
