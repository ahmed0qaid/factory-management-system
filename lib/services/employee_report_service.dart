import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import '../models/advance_model.dart';
import '../models/attendance_model.dart';
import '../models/employee_full_report_model.dart';
import '../models/leave_model.dart';
import '../models/overtime_record_model.dart';
import '../models/payroll_model.dart';
import '../models/penalty_model.dart';
import '../models/profile_model.dart';
import 'appwrite_service.dart';

class EmployeeReportService {
  Map<String, dynamic> _data(models.Row row) {
    final data = {...row.data, 'id': row.$id};
    data['request_date'] ??= data['created_at'];
    data['approved_date'] ??= data['created_at'];
    return data;
  }

  String _dateOnly(DateTime value) => value.toIso8601String().substring(0, 10);

  Future<List<ProfileModel>> getEmployees({int limit = 200}) async {
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      queries: [Query.orderAsc('full_name'), Query.limit(limit)],
    );
    return rows.rows.map((row) => ProfileModel.fromMap(_data(row))).toList();
  }

  Future<EmployeeFullReport> getEmployeeFullReport({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final employeeRow = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: employeeId,
    );
    final employee = ProfileModel.fromMap(_data(employeeRow));

    final results = await Future.wait<List<dynamic>>([
      _safeList(
        () => _getAttendance(employeeId: employeeId, from: from, to: to),
      ),
      _safeList(() => _getPayroll(employeeId: employeeId, from: from, to: to)),
      _safeList(() => _getAdvances(employeeId: employeeId, from: from, to: to)),
      _safeList(
        () => _getPenalties(employeeId: employeeId, from: from, to: to),
      ),
      _safeList(() => _getLeaves(employeeId: employeeId, from: from, to: to)),
      _safeList(() => _getOvertime(employeeId: employeeId, from: from, to: to)),
      _safeList(() => _getDocuments(employeeId: employeeId)),
    ]);

    return EmployeeFullReport(
      employee: employee,
      attendance: results[0].cast<AttendanceRecordModel>(),
      payroll: results[1].cast<PayrollRecordModel>(),
      advances: results[2].cast<AdvanceModel>(),
      penalties: results[3].cast<PenaltyModel>(),
      leaves: results[4].cast<LeaveModel>(),
      overtime: results[5].cast<OvertimeRecordModel>(),
      documents: results[6].cast<models.Row>(),
    );
  }

  Future<List<models.Row>> getAttendanceReport({
    String? employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.attendanceTable,
      employeeId: employeeId,
      dateField: 'work_date',
      from: from,
      to: to,
      orderField: 'work_date',
      limit: limit,
    );
  }

  Future<List<models.Row>> getPayrollReport({
    String? employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.payrollTable,
      employeeId: employeeId,
      dateField: 'created_at',
      from: from,
      to: to,
      orderField: 'created_at',
      limit: limit,
    );
  }

  Future<List<models.Row>> getAdvancesReport({
    String? employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.advancesTable,
      employeeId: employeeId,
      dateField: 'created_at',
      from: from,
      to: to,
      orderField: 'created_at',
      limit: limit,
    );
  }

  Future<List<models.Row>> getPenaltiesReport({
    String? employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.penaltiesTable,
      employeeId: employeeId,
      dateField: 'penalty_date',
      from: from,
      to: to,
      orderField: 'penalty_date',
      limit: limit,
    );
  }

  Future<List<models.Row>> getLeavesReport({
    String? employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.leaveRequestsTable,
      employeeId: employeeId,
      dateField: 'start_date',
      from: from,
      to: to,
      orderField: 'created_at',
      limit: limit,
    );
  }

  Future<List<models.Row>> getOvertimeReport({
    String? employeeId,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.overtimeRecordsTable,
      employeeId: employeeId,
      dateField: 'work_date',
      from: from,
      to: to,
      orderField: 'work_date',
      limit: limit,
    );
  }

  Future<List<models.Row>> getDocumentsReport({
    String? employeeId,
    int limit = 500,
  }) {
    return _listRows(
      tableId: AppConstants.employeeDocumentsTable,
      employeeId: employeeId,
      orderField: r'$createdAt',
      limit: limit,
    );
  }

  Future<List<models.Row>> _listRows({
    required String tableId,
    String? employeeId,
    String? dateField,
    DateTime? from,
    DateTime? to,
    String? orderField,
    int limit = 500,
  }) async {
    final queries = <String>[
      if (employeeId != null) Query.equal('employee_id', employeeId),
      if (dateField != null && from != null)
        Query.greaterThanEqual(
          dateField,
          dateField == 'created_at' ? from.toIso8601String() : _dateOnly(from),
        ),
      if (dateField != null && to != null)
        Query.lessThanEqual(
          dateField,
          dateField == 'created_at' ? to.toIso8601String() : _dateOnly(to),
        ),
      if (orderField != null) Query.orderDesc(orderField),
      Query.limit(limit),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: tableId,
      queries: queries,
    );
    return rows.rows;
  }

  Future<List<T>> _safeList<T>(Future<List<T>> Function() loader) async {
    try {
      return await loader();
    } on AppwriteException {
      return <T>[];
    } catch (_) {
      return <T>[];
    }
  }

  Future<List<AttendanceRecordModel>> _getAttendance({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final queries = <String>[
      Query.equal('employee_id', employeeId),
      Query.orderDesc('work_date'),
      Query.limit(500),
      if (from != null) Query.greaterThanEqual('work_date', _dateOnly(from)),
      if (to != null) Query.lessThanEqual('work_date', _dateOnly(to)),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.attendanceTable,
      queries: queries,
    );
    return rows.rows
        .map((row) => AttendanceRecordModel.fromMap(_data(row)))
        .toList();
  }

  Future<List<PayrollRecordModel>> _getPayroll({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final queries = <String>[
      Query.equal('employee_id', employeeId),
      Query.orderDesc('created_at'),
      Query.limit(200),
      if (from != null)
        Query.greaterThanEqual('created_at', from.toIso8601String()),
      if (to != null) Query.lessThanEqual('created_at', to.toIso8601String()),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.payrollTable,
      queries: queries,
    );
    return rows.rows
        .map((row) => PayrollRecordModel.fromMap(_data(row)))
        .toList();
  }

  Future<List<AdvanceModel>> _getAdvances({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final queries = <String>[
      Query.equal('employee_id', employeeId),
      Query.orderDesc('created_at'),
      Query.limit(200),
      if (from != null)
        Query.greaterThanEqual('created_at', from.toIso8601String()),
      if (to != null) Query.lessThanEqual('created_at', to.toIso8601String()),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.advancesTable,
      queries: queries,
    );
    return rows.rows.map((row) => AdvanceModel.fromMap(_data(row))).toList();
  }

  Future<List<PenaltyModel>> _getPenalties({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final queries = <String>[
      Query.equal('employee_id', employeeId),
      Query.orderDesc('penalty_date'),
      Query.limit(200),
      if (from != null) Query.greaterThanEqual('penalty_date', _dateOnly(from)),
      if (to != null) Query.lessThanEqual('penalty_date', _dateOnly(to)),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.penaltiesTable,
      queries: queries,
    );
    return rows.rows.map((row) => PenaltyModel.fromMap(_data(row))).toList();
  }

  Future<List<LeaveModel>> _getLeaves({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final queries = <String>[
      Query.equal('employee_id', employeeId),
      Query.orderDesc('created_at'),
      Query.limit(200),
      if (from != null) Query.greaterThanEqual('start_date', _dateOnly(from)),
      if (to != null) Query.lessThanEqual('end_date', _dateOnly(to)),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.leaveRequestsTable,
      queries: queries,
    );
    return rows.rows.map((row) => LeaveModel.fromMap(_data(row))).toList();
  }

  Future<List<OvertimeRecordModel>> _getOvertime({
    required String employeeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final queries = <String>[
      Query.equal('employee_id', employeeId),
      Query.orderDesc('work_date'),
      Query.limit(200),
      if (from != null) Query.greaterThanEqual('work_date', _dateOnly(from)),
      if (to != null) Query.lessThanEqual('work_date', _dateOnly(to)),
    ];
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.overtimeRecordsTable,
      queries: queries,
    );
    return rows.rows
        .map((row) => OvertimeRecordModel.fromMap(_data(row)))
        .toList();
  }

  Future<List<models.Row>> _getDocuments({required String employeeId}) async {
    final rows = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeDocumentsTable,
      queries: [
        Query.equal('employee_id', employeeId),
        Query.orderDesc(r'$createdAt'),
        Query.limit(200),
      ],
    );
    return rows.rows;
  }
}
