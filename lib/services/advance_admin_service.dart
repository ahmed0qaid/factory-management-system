import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/advance_model.dart';
import '../models/installment_model.dart';
import 'appwrite_service.dart';
import 'auth_service.dart';
import 'company_context_service.dart';
import 'notification_service.dart';

class AdvanceAdminService {
  Future<void> updateAdvanceStatus({
    required String advanceId,
    required String status,
    String? approvalNote,
    String? rejectionReason,
    num? approvedAmount,
    int? installmentCount,
    String? firstInstallmentMonth,
  }) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    if (companyId == null) throw Exception('No company context selected');

    final currentUser = await AuthService().getCurrentUser();
    if (currentUser == null) throw Exception('No current user');

    final now = DateTime.now().toIso8601String();

    final updateData = <String, dynamic>{
      'status': status,
    };

    if (status == 'approved') {
      if (approvalNote?.isEmpty ?? true) {
        throw Exception('Approval note is required');
      }
      if (approvedAmount == null || approvedAmount <= 0) {
        throw Exception('Approved amount is required and must be > 0');
      }
      if (installmentCount == null || installmentCount <= 0) {
        throw Exception('Installment count is required and must be > 0');
      }
      if (firstInstallmentMonth == null || firstInstallmentMonth.isEmpty) {
        throw Exception('First installment month is required');
      }

      final installmentAmount = approvedAmount / installmentCount;

      updateData['approved_by'] = currentUser.$id;
      updateData['approved_at'] = now;
      updateData['approval_note'] = approvalNote;
      updateData['approved_amount'] = approvedAmount;
      updateData['installment_count'] = installmentCount;
      updateData['installment_amount'] = installmentAmount;
      updateData['first_installment_month'] = firstInstallmentMonth;
      updateData['remaining_amount'] = approvedAmount;
      updateData['repayment_status'] = 'active';

      // 1. Update advance
      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advanceId,
        data: updateData,
      );

      // 2. Fetch the updated advance to get employeeId
      final advRow = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advanceId,
      );
      final employeeId = advRow.data['employee_id']?.toString() ?? '';

      // 3. Generate installments
      await _generateInstallments(
        companyId: companyId,
        advanceId: advanceId,
        employeeId: employeeId,
        approvedAmount: approvedAmount,
        installmentCount: installmentCount,
        firstInstallmentMonth: firstInstallmentMonth,
      );

      // 4. Send notification
      try {
        await NotificationService().createNotification(
          companyId: companyId,
          employeeId: employeeId,
          title: 'تم اعتماد السلفة',
          body: 'تم اعتماد السلفة بمبلغ $approvedAmount',
          type: 'advance',
          referenceTable: AppConstants.advancesTable,
          referenceId: advanceId,
        );
      } catch (e) {
        // Best effort
      }
    } else if (status == 'rejected') {
      if (rejectionReason?.isEmpty ?? true) {
        throw Exception('Rejection reason is required');
      }
      updateData['rejection_reason'] = rejectionReason;

      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advanceId,
        data: updateData,
      );

      final advRow = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advanceId,
      );
      final employeeId = advRow.data['employee_id']?.toString() ?? '';

      try {
        await NotificationService().createNotification(
          companyId: companyId,
          employeeId: employeeId,
          title: 'تم رفض السلفة',
          body: 'تم رفض السلفة للموظف: $rejectionReason',
          type: 'advance',
          referenceTable: AppConstants.advancesTable,
          referenceId: advanceId,
        );
      } catch (e) {
        // Best effort
      }
    } else if (status == 'cancelled') {
      // Must ensure NO installment was deducted yet
      final installments = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advanceInstallmentsTable,
        queries: [
          Query.equal('advance_id', advanceId),
        ],
      );
      if (installments.rows.any((doc) => doc.data['status'] == 'deducted')) {
        throw Exception('لا يمكن إلغاء سلفة تم البدء في سدادها (يوجد قسط مدفوع)');
      }

      if (rejectionReason?.isEmpty ?? true) {
        throw Exception('Reason for cancellation is required');
      }
      updateData['rejection_reason'] = rejectionReason;

      await AppwriteService.tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advancesTable,
        rowId: advanceId,
        data: updateData,
      );

      // Cancel all pending installments
      for (final inst in installments.rows) {
        if (inst.data['status'] == 'pending') {
          await AppwriteService.tablesDB.updateRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.advanceInstallmentsTable,
            rowId: inst.$id,
            data: {'status': 'cancelled'},
          );
        }
      }
    }
  }

  Future<void> _generateInstallments({
    required String companyId,
    required String advanceId,
    required String employeeId,
    required num approvedAmount,
    required int installmentCount,
    required String firstInstallmentMonth,
  }) async {
    // Check if installments already exist to avoid duplicates
    final existing = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advanceInstallmentsTable,
      queries: [
        Query.equal('advance_id', advanceId),
      ],
    );
    if (existing.rows.isNotEmpty) {
      return; // Already generated
    }

    final yearMonth = firstInstallmentMonth.split('-');
    if (yearMonth.length != 2) throw Exception('Invalid firstInstallmentMonth');
    int currentYear = int.parse(yearMonth[0]);
    int currentMonth = int.parse(yearMonth[1]);

    final baseInstallment = num.parse((approvedAmount / installmentCount).toStringAsFixed(2));
    num remaining = approvedAmount;
    final now = DateTime.now().toIso8601String();

    for (int i = 1; i <= installmentCount; i++) {
      num amount = baseInstallment;
      if (i == installmentCount) {
        amount = remaining; // Handle uneven last installment
      } else {
        remaining -= amount;
      }

      final monthStr = currentMonth.toString().padLeft(2, '0');
      final dueMonth = '$currentYear-$monthStr';

      await AppwriteService.tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.advanceInstallmentsTable,
        rowId: 'inst_${advanceId}_$i',
        data: {
          'company_id': companyId,
          'advance_id': advanceId,
          'employee_id': employeeId,
          'installment_number': i,
          'due_month': dueMonth,
          'amount': amount,
          'status': 'pending',
          'created_at': now,
        },
      );

      // Next month
      currentMonth++;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear++;
      }
    }
  }

  Future<List<InstallmentModel>> getInstallmentsForAdvance(String advanceId) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advanceInstallmentsTable,
      queries: [
        Query.equal('advance_id', advanceId),
        Query.orderAsc('installment_number'),
        Query.limit(100),
      ],
    );
    return response.rows.map((row) => InstallmentModel.fromMap(row.data, id: row.$id)).toList();
  }

  Future<List<AdvanceModel>> getAdvances(String companyId) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.orderDesc('created_at'),
        Query.limit(500),
      ],
    );
    return response.rows.map((r) => AdvanceModel.fromMap(r.data..['id'] = r.$id)).toList();
  }
}
