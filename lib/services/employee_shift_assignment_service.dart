import 'package:appwrite/appwrite.dart';
import '../config/constants.dart';
import '../models/employee_shift_assignment_model.dart';
import 'appwrite_service.dart';

class EmployeeShiftAssignmentService {
  Future<List<EmployeeShiftAssignmentModel>> getAssignments(
    String companyId,
  ) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      queries: [Query.equal('company_id', companyId)],
    );
    return response.rows
        .map((r) => EmployeeShiftAssignmentModel.fromMap(r.data, id: r.$id))
        .toList();
  }

  Future<EmployeeShiftAssignmentModel?> getActiveAssignment(
    String employeeId,
  ) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      queries: [
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
    // Check if there is an active assignment for this employee
    final existing = await getActiveAssignment(assignment.employeeId);

    if (existing != null) {
      if (existing.id == assignment.id) {
        // Just update it
        await AppwriteService.tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeShiftAssignmentsTable,
          rowId: assignment.id,
          data: assignment.toMap()
            ..remove('id')
            ..remove('company_id'),
        );
      } else {
        // Disable the old one
        await AppwriteService.tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeShiftAssignmentsTable,
          rowId: existing.id,
          data: {'active': false},
        );
        // Create the new one
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.employeeShiftAssignmentsTable,
          rowId: ID.unique(),
          data: assignment.toMap()..remove('id'),
        );
      }
    } else {
      // Create it
      await AppwriteService.tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeShiftAssignmentsTable,
        rowId: assignment.id.isEmpty ? ID.unique() : assignment.id,
        data: assignment.toMap()..remove('id'),
      );
    }
  }

  Future<void> disableAssignment(String assignmentId) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeShiftAssignmentsTable,
      rowId: assignmentId,
      data: {'active': false},
    );
  }
}
