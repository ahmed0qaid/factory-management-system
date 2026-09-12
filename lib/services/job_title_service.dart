import 'package:appwrite/appwrite.dart';
import '../config/constants.dart';
import '../models/job_title_model.dart';
import 'appwrite_service.dart';

class JobTitleService {
  final TablesDB _db = AppwriteService.tablesDB;

  Future<List<JobTitleModel>> getJobTitles({
    required String companyId,
    bool activeOnly = true,
  }) async {
    try {
      final queries = [Query.equal('company_id', companyId), Query.limit(100)];

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
      final res = await _db.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.jobTitlesTable,
        rowId: ID.unique(),
        data: {'company_id': companyId, 'name': name, 'active': true},
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
      final res = await _db.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        queries: [Query.equal('job_title_id', id), Query.limit(1)],
      );
      return res.rows.isNotEmpty;
    } catch (e) {
      throw Exception('فشل في التحقق من استخدام المسمى الوظيفي: $e');
    }
  }

  Future<void> deleteJobTitle(String id) async {
    try {
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
      // Re-throw if it's our own friendly exception
      if (e.toString().contains('لا يمكن حذف هذا المسمى')) {
        rethrow;
      }
      throw Exception('فشل في حذف المسمى الوظيفي: $e');
    }
  }
}
