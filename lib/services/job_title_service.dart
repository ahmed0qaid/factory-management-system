import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/job_title_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

class JobTitleService {
  final TablesDB _db = AppwriteService.tablesDB;

  List<String> _permissions(String companyId) => [
    Permission.read(Role.team(companyId)),
    Permission.update(Role.team(companyId, AppRoles.hrAdmin)),
    Permission.delete(Role.team(companyId, AppRoles.hrAdmin)),
  ];

  Future<String> _requireRowCompany(String id) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    final row = await _db.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.jobTitlesTable,
      rowId: id,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('المسمى الوظيفي لا يتبع شركة المستخدم الحالية.');
    }
    return companyId;
  }

  Future<List<JobTitleModel>> getJobTitles({
    required String companyId,
    bool activeOnly = true,
  }) async {
    try {
      final scopedCompanyId = await CompanyContextService.requireCompany(
        companyId,
      );
      final queries = [
        Query.equal('company_id', scopedCompanyId),
        Query.limit(100),
      ];
      if (activeOnly) {
        queries.add(Query.equal('active', true));
      }

      final res = await _db.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.jobTitlesTable,
        queries: queries,
      );
      return res.rows.map((doc) => JobTitleModel.fromMap(doc.data)).toList();
    } catch (e) {
      throw Exception('فشل في جلب المسميات الوظيفية: $e');
    }
  }

  Future<JobTitleModel> createJobTitle({
    required String companyId,
    required String name,
  }) async {
    try {
      final scopedCompanyId = await CompanyContextService.requireCompany(
        companyId,
      );
      final res = await _db.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.jobTitlesTable,
        rowId: ID.unique(),
        data: {'company_id': scopedCompanyId, 'name': name, 'active': true},
        permissions: _permissions(scopedCompanyId),
      );
      return JobTitleModel.fromMap(res.data);
    } catch (e) {
      throw Exception('فشل في إضافة المسمى الوظيفي: $e');
    }
  }

  Future<JobTitleModel> updateJobTitle({
    required String id,
    required String name,
    required bool active,
  }) async {
    try {
      await _requireRowCompany(id);
      final res = await _db.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.jobTitlesTable,
        rowId: id,
        data: {'name': name, 'active': active},
      );
      return JobTitleModel.fromMap(res.data);
    } catch (e) {
      throw Exception('فشل في تعديل المسمى الوظيفي: $e');
    }
  }

  Future<void> deactivateJobTitle(String id) async {
    try {
      await _requireRowCompany(id);
      await _db.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.jobTitlesTable,
        rowId: id,
        data: {'active': false},
      );
    } catch (e) {
      throw Exception('فشل في تعطيل المسمى الوظيفي: $e');
    }
  }

  Future<bool> isJobTitleInUse(String id) async {
    try {
      final companyId = await _requireRowCompany(id);
      final res = await _db.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        queries: [
          Query.equal('company_id', companyId),
          Query.equal('job_title_id', id),
          Query.limit(1),
        ],
      );
      return res.rows.isNotEmpty;
    } catch (e) {
      throw Exception('فشل في التحقق من استخدام المسمى الوظيفي: $e');
    }
  }

  Future<void> deleteJobTitle(String id) async {
    try {
      await _requireRowCompany(id);
      final inUse = await isJobTitleInUse(id);
      if (inUse) {
        throw Exception('لا يمكن حذف هذا المسمى لأنه مسند إلى موظف حالياً');
      }
      await _db.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.jobTitlesTable,
        rowId: id,
      );
    } catch (e) {
      if (e.toString().contains('لا يمكن حذف هذا المسمى')) {
        rethrow;
      }
      throw Exception('فشل في حذف المسمى الوظيفي: $e');
    }
  }
}
