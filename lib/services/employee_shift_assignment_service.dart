import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/employee_shift_assignment_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

class EmployeeShiftAssignmentService {
  List<String> _permissions(String companyId) => [
    Permission.read(Role.team(companyId, AppRoles.hrAdmin)),
    Permission.update(Role.team(companyId, AppRoles.hrAdmin)),
    Permission.delete(Role.team(companyId, AppRoles.hrAdmin)),
  ];

  Future<String> _requireCompany(String companyId) {
    return CompanyContextService.requireCompany(companyId);
  }

  Future<void> _requireEmployee(String companyId, String employeeId) async {
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      rowId: employeeId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('الموظف لا يتبع شركة المستخدم الحالية.');
    }
  }

  Future<List<EmployeeShiftAssignmentModel>> getAssignments(
    String companyId,
  ) async {
    final scopedCompanyId = await _requireCompany(companyId);
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      queries: [Query.equal('company_id', scopedCompanyId)],
    );
    return response.rows
        .map((r) => EmployeeShiftAssignmentModel.fromMap(r.data, id: r.$id))
        .toList();
  }

  Future<EmployeeShiftAssignmentModel?> getActiveAssignment(
    String employeeId, {
    String? companyId,
  }) async {
    final scopedCompanyId = companyId == null
        ? await CompanyContextService.getCurrentCompanyId()
        : await _requireCompany(companyId);
    await _requireEmployee(scopedCompanyId, employeeId);
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      queries: [
        Query.equal('company_id', scopedCompanyId),
        Query.equal('employee_id', employeeId),
        Query.equal('active', true),
      ],
    );
    if (response.rows.isEmpty) return null;
    return EmployeeShiftAssignmentModel.fromMap(
      response.rows.first.data,
      id: response.rows.first.$id,
    );
  }

  Future<void> saveAssignment(EmployeeShiftAssignmentModel assignment) async {
    final companyId = await _requireCompany(assignment.companyId);
    await _requireEmployee(companyId, assignment.employeeId);
    final existing = await getActiveAssignment(
      assignment.employeeId,
      companyId: companyId,
    );

    if (existing != null) {
      if (existing.id == assignment.id) {
        await AppwriteService.tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeShiftAssignmentsTable,
          rowId: assignment.id,
          data: assignment.toMap()
            ..remove('id')
            ..remove('company_id'),
        );
      } else {
        await AppwriteService.tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeShiftAssignmentsTable,
          rowId: existing.id,
          data: {'active': false},
        );
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeShiftAssignmentsTable,
          rowId: ID.unique(),
          data: assignment.toMap()..remove('id'),
          permissions: _permissions(companyId),
        );
      }
    } else {
      await AppwriteService.tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeShiftAssignmentsTable,
        rowId: assignment.id.isEmpty ? ID.unique() : assignment.id,
        data: assignment.toMap()..remove('id'),
        permissions: _permissions(companyId),
      );
    }
  }

  Future<void> disableAssignment(String assignmentId) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      rowId: assignmentId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('تعيين الدوام لا يتبع شركة المستخدم الحالية.');
    }
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      rowId: assignmentId,
      data: {'active': false},
    );
  }
}
