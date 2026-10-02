import 'package:appwrite/appwrite.dart';
import '../config/constants.dart';
import 'appwrite_service.dart';
import 'auth_service.dart';
import 'company_context_service.dart';

class PayrollPeriodModel {
  final String id;
  final String companyId;
  final String periodKey;
  final int year;
  final int month;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PayrollPeriodModel({
    required this.id,
    required this.companyId,
    required this.periodKey,
    required this.year,
    required this.month,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory PayrollPeriodModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return PayrollPeriodModel(
      id: id ?? map['$id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      periodKey: map['period_key'] ?? '',
      year: map['year'] as int? ?? 1970,
      month: map['month'] as int? ?? 1,
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      status: map['status'] ?? 'open',
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }
}

class PayrollPeriodService {
  static String generatePeriodKey(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }


  static ({DateTime periodStart, DateTime periodEnd}) getCurrentPayrollPeriod(DateTime now) {
    return resolvePeriodRange(now.year, now.month);
  }
  static ({DateTime periodStart, DateTime periodEnd}) resolvePeriodRange(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return (periodStart: start, periodEnd: end);
  }

  static bool isWorkingDay(DateTime date) {
    return date.weekday != DateTime.friday;
  }

  static int countWorkingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (isWorkingDay(current)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  Future<PayrollPeriodModel> getOrCreatePeriod(String companyId, int year, int month) async {
    final periodKey = generatePeriodKey(year, month);
    final existing = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollPeriodsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('period_key', periodKey),
      ],
    );

    if (existing.rows.isNotEmpty) {
      return PayrollPeriodModel.fromMap(existing.rows.first.data, id: existing.rows.first.$id);
    }

    // Create
    final currentUser = await AuthService().getCurrentUser();
    final range = resolvePeriodRange(year, month);
    final periodId = ID.unique();

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollPeriodsTable,
      rowId: periodId,
      data: {
        'company_id': companyId,
        'period_key': periodKey,
        'year': year,
        'month': month,
        'start_date': range.periodStart.toIso8601String(),
        'end_date': range.periodEnd.toIso8601String(),
        'status': 'open',
        'created_by': currentUser?.$id,
        'created_at': DateTime.now().toIso8601String(),
      },
    );

    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollPeriodsTable,
      rowId: periodId,
    );
    return PayrollPeriodModel.fromMap(row.data, id: row.$id);
  }

  Future<List<PayrollPeriodModel>> listPeriods(String companyId) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollPeriodsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.orderDesc('period_key'),
        Query.limit(100),
      ],
    );
    return response.rows.map((e) => PayrollPeriodModel.fromMap(e.data, id: e.$id)).toList();
  }

  Future<void> updatePeriodStatus(String periodId, String newStatus) async {
    // If closing, we should ideally check for pending AttendanceReview. 
    // This is required by Phase 11.
    if (newStatus == 'closed') {
      final periodRow = await AppwriteService.tablesDB.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.payrollPeriodsTable,
        rowId: periodId,
      );
      final period = PayrollPeriodModel.fromMap(periodRow.data, id: periodId);

      // Check unresolved attendance
      final pendingAtt = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.attendanceTable,
        queries: [
          Query.equal('company_id', period.companyId),
          Query.greaterThanEqual('check_in', period.startDate.toIso8601String()),
          Query.lessThanEqual('check_in', period.endDate.toIso8601String()),
          Query.equal('is_reviewed', false),
        ],
      );

      // We only care if there is missing check-out or absent without leave that needs review,
      // but let's assume any `is_reviewed == false` AND `status == 'missing_checkout'` is unresolved.
      // Phase 11 explicitly says: "تحقق من unresolved attendance داخل الفترة. إذا وجد: ارفض مع عدد الحالات."
      int unresolvedCount = 0;
      for (final att in pendingAtt.rows) {
         final status = att.data['status']?.toString() ?? '';
         if (status == 'missing_checkout' || status == 'absent_unjustified' || status == 'late_unjustified') {
           unresolvedCount++;
         }
      }
      if (unresolvedCount > 0) {
        throw Exception('لا يمكن إغلاق الفترة. يوجد $unresolvedCount حالة حضور غير محسومة (تحتاج مراجعة).');
      }
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollPeriodsTable,
      rowId: periodId,
      data: {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<PayrollPeriodModel> getPeriod(String periodId) async {
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollPeriodsTable,
      rowId: periodId,
    );
    return PayrollPeriodModel.fromMap(row.data, id: row.$id);
  }
}
