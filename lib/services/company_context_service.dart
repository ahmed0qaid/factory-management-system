import '../config/constants.dart';
import '../models/profile_model.dart';
import 'appwrite_service.dart';

/// Resolves the authenticated user's company from their persisted profile.
///
/// Company-scoped services should use this instead of hard-coded team IDs or
/// trusting a company ID copied from a row selected in the UI.
class CompanyContextService {
  CompanyContextService._();

  static Future<ProfileModel> getCurrentProfile() async {
    final user = await AppwriteService.account.get();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: user.$id,
    );
    final profile = ProfileModel.fromMap({...row.data, 'id': row.$id});
    if (profile.companyId.trim().isEmpty) {
      throw StateError('حساب المستخدم غير مرتبط بشركة.');
    }
    return profile;
  }

  static Future<String> getCurrentCompanyId() async {
    return (await getCurrentProfile()).companyId;
  }

  static Future<String> requireCompany(String companyId) async {
    final currentCompanyId = await getCurrentCompanyId();
    if (companyId.trim().isEmpty || companyId != currentCompanyId) {
      throw StateError('لا يمكن تنفيذ العملية على بيانات شركة أخرى.');
    }
    return currentCompanyId;
  }
}
