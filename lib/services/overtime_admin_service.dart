import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/overtime_record_model.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

/// Company-scoped management operations for overtime records.
///
/// The biometric service remains responsible for import/processing. Approval
/// and payment lookups are separated here so management actions cannot cross
/// company boundaries by row ID.
class OvertimeAdminService {
  Future<String> _companyId() => CompanyContextService.getCurrentCompanyId();

  Future<void> _requireRow(String overtimeId) async {
    final companyId = await _companyId();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('سجل الوقت الإضافي لا يتبع شركة المستخدم الحالية.');
    }
  }

  Future<List<OvertimeRecordModel>> getPendingOvertime() async {
    final companyId = await _companyId();
    final docs = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('approval_status', 'pending'),
        Query.orderDesc('created_at'),
      ],
    );
    return docs.rows
        .map((d) => OvertimeRecordModel.fromMap(d.data, id: d.$id))
        .toList();
  }

  Future<void> updateOvertimeStatus(
    String overtimeId,
    String approvalStatus,
  ) async {
    if (approvalStatus != 'approved' && approvalStatus != 'rejected') {
      throw ArgumentError('حالة اعتماد الوقت الإضافي غير صالحة.');
    }
    await _requireRow(overtimeId);
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
      data: {
        'approval_status': approvalStatus,
        if (approvalStatus == 'approved')
          'approved_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> payOvertime(String overtimeId, num amount) async {
    if (amount < 0) {
      throw ArgumentError('مبلغ الوقت الإضافي غير صالح.');
    }
    await _requireRow(overtimeId);
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      rowId: overtimeId,
      data: {
        'payment_status': 'paid',
        'paid_amount': amount,
        'paid_at': DateTime.now().toIso8601String(),
      },
    );
  }
}
